// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {TierLib} from "../libraries/TierLib.sol";

/**
 * @title ITKOStaking
 * @notice Interface for TKO staking contract
 */
interface ITKOStaking {
    /// @notice User staking position data
    struct StakeInfo {
        uint256 amount;
        uint256 lockEndTime;
        uint256 lockDuration;
        uint256 lastStakeTime;
    }

    /// @notice Stake TKO tokens with optional lock duration
    function stake(uint256 amount, uint256 lockDays) external;

    /// @notice Unstake TKO tokens
    function unstake(uint256 amount) external;

    /// @notice Emergency withdraw with penalty
    function emergencyWithdraw() external;

    /// @notice Calculate user's current tier
    function calculateTier(address user) external view returns (TierLib.Tier);

    /// @notice Get user's effective stake with lock multiplier
    function getEffectiveStake(address user) external view returns (uint256);

    /// @notice Get user's stake information
    function getUserStakeInfo(address user) external view returns (
        uint256 amount,
        uint256 lockEndTime,
        uint256 lockDuration,
        TierLib.Tier tier,
        uint256 effectiveStake
    );

    /// @notice Check if user's stake is locked
    function isStakeLocked(address user) external view returns (
        bool isLocked,
        uint256 unlockTime
    );

    /// @notice Get total staked amount
    function totalStaked() external view returns (uint256);
}
