// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import {TransientReentrancyGuard} from "../libraries/TransientReentrancyGuard.sol";
import {TierLib} from "../libraries/TierLib.sol";

// Interface for staking contract
interface ITKOStaking {
    function calculateTier(address user) external view returns (TierLib.Tier);
    function getEffectiveStake(address user) external view returns (uint256);
}

/**
 * @title IDOPool
 * @author NusantaraPad Team
 * @notice Individual IDO pool with participation, vesting, and tier-based allocation
 * @dev Supports both Merkle proof whitelisting and on-chain tier verification
 * @custom:security-contact security@nusantarapad.io
 */
contract IDOPool is TransientReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;
    using TierLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Pool configuration parameters
    struct PoolConfig {
        address saleToken;           // Token being sold
        address paymentToken;        // Payment token (address(0) for BNB)
        uint256 tokenPrice;          // Price per token in payment token units
        uint256 softCap;             // Minimum raise amount
        uint256 hardCap;             // Maximum raise amount
        uint256 minPurchase;         // Minimum purchase per user
        uint256 maxPurchase;         // Maximum purchase per user (base allocation)
        uint256 startTime;           // Sale start timestamp
        uint256 endTime;             // Sale end timestamp
        bool requireWhitelist;       // If true, requires Merkle proof
    }

    /// @notice Vesting schedule configuration
    struct VestingConfig {
        uint256 tgePercentage;       // Percentage released at TGE (basis points)
        uint256 cliffDuration;       // Cliff period in seconds
        uint256 vestingDuration;     // Total vesting duration in seconds
        uint256 slicePeriod;         // Release period (e.g., 30 days)
    }

    /// @notice Individual participant data
    struct Participant {
        uint256 contributed;         // Amount contributed in payment token
        uint256 tokenAllocation;     // Token allocation based on contribution
        uint256 claimed;             // Amount of tokens claimed
        bool refunded;               // Whether user has been refunded
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Participated(
        address indexed user,
        uint256 amount,
        uint256 tokenAllocation,
        TierLib.Tier tier
    );

    event TokensClaimed(address indexed user, uint256 amount);
    event Refunded(address indexed user, uint256 amount);
    event PoolFinalized(bool successful, uint256 totalRaised);
    event MerkleRootUpdated(bytes32 oldRoot, bytes32 newRoot);
    event TokensDeposited(uint256 amount);
    event FundsWithdrawn(address indexed to, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SaleNotActive();
    error SaleNotEnded();
    error SaleAlreadyFinalized();
    error InvalidMerkleProof();
    error ExceedsMaxPurchase();
    error BelowMinPurchase();
    error HardCapReached();
    error SoftCapNotMet();
    error AlreadyRefunded();
    error NothingToClaim();
    error NoContribution();
    error InsufficientTier();
    error InvalidPayment();
    error PoolNotFinalized();
    error TokensNotDeposited();
    error ZeroAddress();

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Pool configuration
    PoolConfig public config;

    /// @notice Vesting configuration
    VestingConfig public vesting;

    /// @notice Staking contract for tier verification
    ITKOStaking public immutable stakingContract;

    /// @notice Merkle root for whitelist verification
    bytes32 public merkleRoot;

    /// @notice Total amount raised in payment tokens
    uint256 public totalRaised;

    /// @notice Whether the pool has been finalized
    bool public finalized;

    /// @notice Whether sale tokens have been deposited
    bool public tokensDeposited;

    /// @notice TGE (Token Generation Event) timestamp
    uint256 public tgeTimestamp;

    /// @notice Participant data mapping
    mapping(address => Participant) public participants;

    /// @notice Total number of participants
    uint256 public participantCount;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize the IDO pool
     * @param _config Pool configuration
     * @param _vesting Vesting configuration
     * @param _stakingContract Address of TKO staking contract
     * @param _owner Pool owner address
     */
    constructor(
        PoolConfig memory _config,
        VestingConfig memory _vesting,
        address _stakingContract,
        address _owner
    ) Ownable(_owner) {
        if (_config.saleToken == address(0)) revert ZeroAddress();
        if (_stakingContract == address(0)) revert ZeroAddress();

        config = _config;
        vesting = _vesting;
        stakingContract = ITKOStaking(_stakingContract);
    }

    /*//////////////////////////////////////////////////////////////
                          PARTICIPATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Participate in the IDO
     * @param amount Amount of payment tokens (ignored for BNB)
     * @param merkleProof Merkle proof for whitelist verification
     */
    function participate(
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external payable nonReentrant whenNotPaused {
        // Validate timing
        if (block.timestamp < config.startTime || block.timestamp > config.endTime) {
            revert SaleNotActive();
        }

        // Handle BNB or token payment
        uint256 paymentAmount;
        if (config.paymentToken == address(0)) {
            paymentAmount = msg.value;
        } else {
            paymentAmount = amount;
            if (msg.value > 0) revert InvalidPayment();
        }

        // Validate amount
        if (paymentAmount < config.minPurchase) revert BelowMinPurchase();
        if (totalRaised + paymentAmount > config.hardCap) revert HardCapReached();

        // Get user tier and validate
        TierLib.Tier userTier = stakingContract.calculateTier(msg.sender);
        
        // Validate whitelist if required
        if (config.requireWhitelist) {
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) {
                revert InvalidMerkleProof();
            }
        } else {
            // Without whitelist, require at least Bronze tier
            if (userTier == TierLib.Tier.None) revert InsufficientTier();
        }

        // Calculate max allocation based on tier
        uint256 maxAllocation = _calculateMaxAllocation(userTier);
        
        Participant storage participant = participants[msg.sender];
        
        if (participant.contributed + paymentAmount > maxAllocation) {
            revert ExceedsMaxPurchase();
        }

        // Update participant state
        if (participant.contributed == 0) {
            participantCount++;
        }

        participant.contributed += paymentAmount;
        participant.tokenAllocation += (paymentAmount * 1e18) / config.tokenPrice;

        totalRaised += paymentAmount;

        // Transfer payment tokens if not BNB
        if (config.paymentToken != address(0)) {
            IERC20(config.paymentToken).safeTransferFrom(
                msg.sender,
                address(this),
                paymentAmount
            );
        }

        emit Participated(
            msg.sender,
            paymentAmount,
            participant.tokenAllocation,
            userTier
        );
    }

    /**
     * @notice Calculate maximum allocation based on tier
     * @param tier User's tier
     * @return maxAllocation Maximum payment amount allowed
     */
    function _calculateMaxAllocation(TierLib.Tier tier) internal view returns (uint256 maxAllocation) {
        uint256 multiplier = TierLib.getAllocationMultiplier(tier);
        
        if (tier == TierLib.Tier.Bronze) {
            // Bronze gets base allocation (lottery)
            return config.maxPurchase;
        }
        
        // Guaranteed tiers get multiplied allocation
        return (config.maxPurchase * multiplier) / 10000;
    }

    /*//////////////////////////////////////////////////////////////
                            CLAIMING LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Claim vested tokens
     */
    function claim() external nonReentrant {
        if (!finalized) revert PoolNotFinalized();
        if (!tokensDeposited) revert TokensNotDeposited();
        if (totalRaised < config.softCap) revert SoftCapNotMet();

        Participant storage participant = participants[msg.sender];
        
        if (participant.contributed == 0) revert NoContribution();

        uint256 claimable = _calculateClaimable(msg.sender);
        if (claimable == 0) revert NothingToClaim();

        participant.claimed += claimable;

        IERC20(config.saleToken).safeTransfer(msg.sender, claimable);

        emit TokensClaimed(msg.sender, claimable);
    }

    /**
     * @notice Calculate claimable tokens for a user
     * @param user User address
     * @return claimable Amount of tokens that can be claimed
     */
    function _calculateClaimable(address user) internal view returns (uint256 claimable) {
        Participant storage participant = participants[user];
        
        if (participant.tokenAllocation == 0) return 0;

        uint256 vested = _calculateVested(participant.tokenAllocation);
        claimable = vested - participant.claimed;
    }

    /**
     * @notice Calculate vested amount based on schedule
     * @param totalAllocation Total token allocation
     * @return vested Amount of tokens vested
     */
    function _calculateVested(uint256 totalAllocation) internal view returns (uint256 vested) {
        if (tgeTimestamp == 0) return 0;
        
        // TGE release
        uint256 tgeAmount = (totalAllocation * vesting.tgePercentage) / 10000;
        
        // If before cliff, only TGE
        uint256 cliffEnd = tgeTimestamp + vesting.cliffDuration;
        if (block.timestamp < cliffEnd) {
            return tgeAmount;
        }

        // Calculate linear vesting after cliff
        uint256 vestingEnd = cliffEnd + vesting.vestingDuration;
        uint256 vestingAmount = totalAllocation - tgeAmount;

        if (block.timestamp >= vestingEnd) {
            return totalAllocation;
        }

        uint256 timeElapsed = block.timestamp - cliffEnd;
        uint256 slicesPassed = timeElapsed / vesting.slicePeriod;
        uint256 totalSlices = vesting.vestingDuration / vesting.slicePeriod;

        uint256 vestedFromSchedule = (vestingAmount * slicesPassed) / totalSlices;
        
        return tgeAmount + vestedFromSchedule;
    }

    /**
     * @notice Get claimable amount for a user (view function)
     * @param user User address
     * @return claimable Amount that can be claimed now
     * @return totalVested Total vested amount
     * @return totalAllocation Total allocation
     */
    function getClaimableInfo(address user) external view returns (
        uint256 claimable,
        uint256 totalVested,
        uint256 totalAllocation
    ) {
        Participant storage participant = participants[user];
        totalAllocation = participant.tokenAllocation;
        totalVested = _calculateVested(totalAllocation);
        claimable = totalVested - participant.claimed;
    }

    /*//////////////////////////////////////////////////////////////
                             REFUND LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Request refund if soft cap not met
     */
    function refund() external nonReentrant {
        if (!finalized) revert PoolNotFinalized();
        if (totalRaised >= config.softCap) revert SoftCapNotMet();

        Participant storage participant = participants[msg.sender];
        
        if (participant.contributed == 0) revert NoContribution();
        if (participant.refunded) revert AlreadyRefunded();

        uint256 refundAmount = participant.contributed;
        participant.refunded = true;

        // Refund BNB or tokens
        if (config.paymentToken == address(0)) {
            (bool success,) = msg.sender.call{value: refundAmount}("");
            require(success, "BNB transfer failed");
        } else {
            IERC20(config.paymentToken).safeTransfer(msg.sender, refundAmount);
        }

        emit Refunded(msg.sender, refundAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set Merkle root for whitelist
     * @param _merkleRoot New Merkle root
     */
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        emit MerkleRootUpdated(merkleRoot, _merkleRoot);
        merkleRoot = _merkleRoot;
    }

    /**
     * @notice Deposit sale tokens into the pool
     * @param amount Amount of tokens to deposit
     */
    function depositTokens(uint256 amount) external onlyOwner {
        IERC20(config.saleToken).safeTransferFrom(msg.sender, address(this), amount);
        tokensDeposited = true;
        emit TokensDeposited(amount);
    }

    /**
     * @notice Finalize the pool after sale ends
     */
    function finalize() external onlyOwner {
        if (block.timestamp < config.endTime) revert SaleNotEnded();
        if (finalized) revert SaleAlreadyFinalized();

        finalized = true;
        
        if (totalRaised >= config.softCap) {
            tgeTimestamp = block.timestamp;
        }

        emit PoolFinalized(totalRaised >= config.softCap, totalRaised);
    }

    /**
     * @notice Withdraw raised funds (only if successful)
     * @param to Address to send funds
     */
    function withdrawFunds(address to) external onlyOwner {
        if (!finalized) revert PoolNotFinalized();
        if (totalRaised < config.softCap) revert SoftCapNotMet();

        uint256 amount;
        if (config.paymentToken == address(0)) {
            amount = address(this).balance;
            (bool success,) = to.call{value: amount}("");
            require(success, "BNB transfer failed");
        } else {
            amount = IERC20(config.paymentToken).balanceOf(address(this));
            IERC20(config.paymentToken).safeTransfer(to, amount);
        }

        emit FundsWithdrawn(to, amount);
    }

    /**
     * @notice Pause pool operations
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause pool operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get pool status
     * @return isActive Whether sale is currently active
     * @return isFilled Whether hard cap is reached
     * @return progress Current progress (basis points)
     */
    function getPoolStatus() external view returns (
        bool isActive,
        bool isFilled,
        uint256 progress
    ) {
        isActive = block.timestamp >= config.startTime && 
                   block.timestamp <= config.endTime &&
                   totalRaised < config.hardCap;
        
        isFilled = totalRaised >= config.hardCap;
        progress = config.hardCap > 0 ? (totalRaised * 10000) / config.hardCap : 0;
    }

    /**
     * @notice Get user's max allocation based on current tier
     * @param user User address
     * @return maxAllocation Maximum contribution allowed
     * @return currentContribution Current contribution amount
     * @return remaining Remaining allocation
     */
    function getUserAllocation(address user) external view returns (
        uint256 maxAllocation,
        uint256 currentContribution,
        uint256 remaining
    ) {
        TierLib.Tier tier = stakingContract.calculateTier(user);
        maxAllocation = _calculateMaxAllocation(tier);
        currentContribution = participants[user].contributed;
        remaining = maxAllocation > currentContribution ? maxAllocation - currentContribution : 0;
    }

    /// @notice Receive function for BNB
    receive() external payable {}
}
