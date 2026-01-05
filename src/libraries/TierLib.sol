// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title TierLib
 * @author NusantaraPad Team
 * @notice Library for tier calculation and allocation multipliers
 * @dev Defines tier thresholds and provides helper functions for tier logic
 */
library TierLib {
    /// @notice User tier levels based on effective stake
    enum Tier {
        None,      // < 500 TKO - No participation
        Bronze,    // >= 500 TKO - Lottery allocation
        Silver,    // >= 2,000 TKO - Guaranteed 1x allocation
        Gold,      // >= 10,000 TKO - Guaranteed 3x allocation
        Platinum   // >= 50,000 TKO - Guaranteed 10x + Private sales
    }

    /// @dev Tier thresholds in TKO (18 decimals)
    uint256 internal constant BRONZE_THRESHOLD = 500 * 1e18;
    uint256 internal constant SILVER_THRESHOLD = 2_000 * 1e18;
    uint256 internal constant GOLD_THRESHOLD = 10_000 * 1e18;
    uint256 internal constant PLATINUM_THRESHOLD = 50_000 * 1e18;

    /// @dev Allocation multipliers (basis points, 10000 = 1x)
    uint256 internal constant BRONZE_MULTIPLIER = 0;       // Lottery only
    uint256 internal constant SILVER_MULTIPLIER = 10_000;  // 1x
    uint256 internal constant GOLD_MULTIPLIER = 30_000;    // 3x
    uint256 internal constant PLATINUM_MULTIPLIER = 100_000; // 10x

    /// @dev Lock duration multipliers (basis points, 10000 = 1x)
    uint256 internal constant NO_LOCK_MULTIPLIER = 10_000;     // 1.0x
    uint256 internal constant LOCK_30_MULTIPLIER = 12_000;     // 1.2x
    uint256 internal constant LOCK_60_MULTIPLIER = 15_000;     // 1.5x
    uint256 internal constant LOCK_90_MULTIPLIER = 20_000;     // 2.0x

    /**
     * @notice Calculate tier based on effective stake amount
     * @param effectiveStake The user's stake multiplied by lock duration bonus
     * @return tier The calculated tier
     */
    function calculateTier(uint256 effectiveStake) internal pure returns (Tier tier) {
        if (effectiveStake >= PLATINUM_THRESHOLD) {
            return Tier.Platinum;
        } else if (effectiveStake >= GOLD_THRESHOLD) {
            return Tier.Gold;
        } else if (effectiveStake >= SILVER_THRESHOLD) {
            return Tier.Silver;
        } else if (effectiveStake >= BRONZE_THRESHOLD) {
            return Tier.Bronze;
        }
        return Tier.None;
    }

    /**
     * @notice Get allocation multiplier for a given tier
     * @param tier The user's tier
     * @return multiplier The allocation multiplier in basis points
     */
    function getAllocationMultiplier(Tier tier) internal pure returns (uint256 multiplier) {
        if (tier == Tier.Platinum) return PLATINUM_MULTIPLIER;
        if (tier == Tier.Gold) return GOLD_MULTIPLIER;
        if (tier == Tier.Silver) return SILVER_MULTIPLIER;
        return BRONZE_MULTIPLIER;
    }

    /**
     * @notice Get lock duration multiplier
     * @param lockDays Number of days the stake is locked
     * @return multiplier The lock multiplier in basis points
     */
    function getLockMultiplier(uint256 lockDays) internal pure returns (uint256 multiplier) {
        if (lockDays >= 90) return LOCK_90_MULTIPLIER;
        if (lockDays >= 60) return LOCK_60_MULTIPLIER;
        if (lockDays >= 30) return LOCK_30_MULTIPLIER;
        return NO_LOCK_MULTIPLIER;
    }

    /**
     * @notice Check if tier is eligible for guaranteed allocation
     * @param tier The user's tier
     * @return isGuaranteed True if guaranteed allocation
     */
    function isGuaranteedTier(Tier tier) internal pure returns (bool isGuaranteed) {
        return tier >= Tier.Silver;
    }

    /**
     * @notice Check if tier is eligible for private sales
     * @param tier The user's tier
     * @return isPrivate True if eligible for private sales
     */
    function isPrivateTier(Tier tier) internal pure returns (bool isPrivate) {
        return tier == Tier.Platinum;
    }
}
