// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {IDOPool} from "./IDOPool.sol";
import {TierLib} from "../libraries/TierLib.sol";

/**
 * @title IDOFactory
 * @author NusantaraPad Team
 * @notice Factory contract for deploying IDO pools with deterministic addresses
 * @dev Uses CREATE2 for predictable pool addresses
 * @custom:security-contact security@nusantarapad.io
 */
contract IDOFactory is Ownable, Pausable {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event PoolCreated(
        address indexed pool,
        address indexed saleToken,
        uint256 hardCap,
        uint256 startTime,
        uint256 endTime
    );

    event StakingContractUpdated(address oldStaking, address newStaking);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidStakingContract();
    error InvalidPoolConfig();
    error PoolAlreadyExists();

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Address of the TKO staking contract
    address public stakingContract;

    /// @notice Array of all deployed pool addresses
    address[] public pools;

    /// @notice Mapping to check if an address is a valid pool
    mapping(address => bool) public isPool;

    /// @notice Mapping from salt to pool address
    mapping(bytes32 => address) public poolBySalt;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize the factory
     * @param _stakingContract Address of TKO staking contract
     * @param _owner Factory owner address
     */
    constructor(address _stakingContract, address _owner) Ownable(_owner) {
        if (_stakingContract == address(0)) revert InvalidStakingContract();
        stakingContract = _stakingContract;
    }

    /*//////////////////////////////////////////////////////////////
                            FACTORY LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Create a new IDO pool
     * @param config Pool configuration
     * @param vesting Vesting configuration
     * @param salt Unique salt for CREATE2 deployment
     * @return pool Address of the deployed pool
     */
    function createPool(
        IDOPool.PoolConfig calldata config,
        IDOPool.VestingConfig calldata vesting,
        bytes32 salt
    ) external onlyOwner whenNotPaused returns (address pool) {
        // Validate config
        if (config.saleToken == address(0)) revert InvalidPoolConfig();
        if (config.hardCap == 0 || config.softCap > config.hardCap) revert InvalidPoolConfig();
        if (config.startTime >= config.endTime) revert InvalidPoolConfig();
        if (config.startTime < block.timestamp) revert InvalidPoolConfig();

        // Check salt hasn't been used
        if (poolBySalt[salt] != address(0)) revert PoolAlreadyExists();

        // Deploy pool using CREATE2
        bytes memory bytecode = abi.encodePacked(
            type(IDOPool).creationCode,
            abi.encode(config, vesting, stakingContract, owner())
        );

        assembly {
            pool := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(pool)) { revert(0, 0) }
        }

        // Register pool
        pools.push(pool);
        isPool[pool] = true;
        poolBySalt[salt] = pool;

        emit PoolCreated(
            pool,
            config.saleToken,
            config.hardCap,
            config.startTime,
            config.endTime
        );
    }

    /**
     * @notice Compute the address of a pool before deployment
     * @param config Pool configuration
     * @param vesting Vesting configuration
     * @param salt Unique salt
     * @return predicted The predicted pool address
     */
    function computePoolAddress(
        IDOPool.PoolConfig calldata config,
        IDOPool.VestingConfig calldata vesting,
        bytes32 salt
    ) external view returns (address predicted) {
        bytes memory bytecode = abi.encodePacked(
            type(IDOPool).creationCode,
            abi.encode(config, vesting, stakingContract, owner())
        );

        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(bytecode)
            )
        );

        predicted = address(uint160(uint256(hash)));
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get all deployed pool addresses
     * @return Array of pool addresses
     */
    function getAllPools() external view returns (address[] memory) {
        return pools;
    }

    /**
     * @notice Get total number of pools
     * @return Total pool count
     */
    function getPoolCount() external view returns (uint256) {
        return pools.length;
    }

    /**
     * @notice Get pool addresses with pagination
     * @param offset Starting index
     * @param limit Maximum number of pools to return
     * @return poolList Array of pool addresses
     */
    function getPools(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory poolList) {
        uint256 totalPools = pools.length;
        
        if (offset >= totalPools) {
            return new address[](0);
        }

        uint256 remaining = totalPools - offset;
        uint256 count = remaining < limit ? remaining : limit;

        poolList = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            poolList[i] = pools[offset + i];
        }
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Update staking contract address
     * @param _stakingContract New staking contract address
     */
    function setStakingContract(address _stakingContract) external onlyOwner {
        if (_stakingContract == address(0)) revert InvalidStakingContract();
        
        emit StakingContractUpdated(stakingContract, _stakingContract);
        stakingContract = _stakingContract;
    }

    /**
     * @notice Pause pool creation
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause pool creation
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
