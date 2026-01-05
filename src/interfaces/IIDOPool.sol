// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {TierLib} from "../libraries/TierLib.sol";

/**
 * @title IIDOPool
 * @notice Interface for IDO pool contracts
 */
interface IIDOPool {
    /// @notice Pool configuration parameters
    struct PoolConfig {
        address saleToken;
        address paymentToken;
        uint256 tokenPrice;
        uint256 softCap;
        uint256 hardCap;
        uint256 minPurchase;
        uint256 maxPurchase;
        uint256 startTime;
        uint256 endTime;
        bool requireWhitelist;
    }

    /// @notice Vesting schedule configuration
    struct VestingConfig {
        uint256 tgePercentage;
        uint256 cliffDuration;
        uint256 vestingDuration;
        uint256 slicePeriod;
    }

    /// @notice Participate in the IDO
    function participate(uint256 amount, bytes32[] calldata merkleProof) external payable;

    /// @notice Claim vested tokens
    function claim() external;

    /// @notice Request refund if soft cap not met
    function refund() external;

    /// @notice Get pool status
    function getPoolStatus() external view returns (
        bool isActive,
        bool isFilled,
        uint256 progress
    );

    /// @notice Get user's allocation info
    function getUserAllocation(address user) external view returns (
        uint256 maxAllocation,
        uint256 currentContribution,
        uint256 remaining
    );

    /// @notice Get claimable token info
    function getClaimableInfo(address user) external view returns (
        uint256 claimable,
        uint256 totalVested,
        uint256 totalAllocation
    );
}
