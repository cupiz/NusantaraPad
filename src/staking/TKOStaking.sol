// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {TransientReentrancyGuard} from "../libraries/TransientReentrancyGuard.sol";
import {TierLib} from "../libraries/TierLib.sol";

/**
 * @title TKOStaking
 * @author NusantaraPad Team
 * @notice Staking contract for $TKO tokens with tier-based allocation system
 * @dev Implements lock-up multipliers for enhanced tier calculation
 * @custom:security-contact security@nusantarapad.io
 */
contract TKOStaking is TransientReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;
    using TierLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice User staking position data
    struct StakeInfo {
        uint256 amount;          // Total staked amount
        uint256 lockEndTime;     // Timestamp when lock expires (0 = no lock)
        uint256 lockDuration;    // Original lock duration in days
        uint256 lastStakeTime;   // Last stake timestamp for cooldown
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a user stakes TKO
    event Staked(
        address indexed user,
        uint256 amount,
        uint256 lockDuration,
        uint256 lockEndTime
    );

    /// @notice Emitted when a user unstakes TKO
    event Unstaked(address indexed user, uint256 amount);

    /// @notice Emitted when a user performs emergency withdrawal
    event EmergencyWithdraw(address indexed user, uint256 amount, uint256 penalty);

    /// @notice Emitted when emergency penalty rate is updated
    event EmergencyPenaltyUpdated(uint256 oldPenalty, uint256 newPenalty);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when stake amount is zero
    error ZeroAmount();

    /// @notice Thrown when user has insufficient staked balance
    error InsufficientBalance();

    /// @notice Thrown when trying to unstake during lock period
    error StakeLocked(uint256 unlockTime);

    /// @notice Thrown when lock duration is invalid
    error InvalidLockDuration();

    /// @notice Thrown when user has no stake to withdraw
    error NoStakeFound();

    /// @notice Thrown when cooldown period has not passed
    error CooldownActive(uint256 cooldownEnd);

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The TKO token contract
    IERC20 public immutable tkoToken;

    /// @notice Minimum cooldown between stakes (prevents gaming)
    uint256 public constant STAKE_COOLDOWN = 1 hours;

    /// @notice Emergency withdrawal penalty (basis points, 1000 = 10%)
    uint256 public emergencyPenaltyBps = 1000;

    /// @notice Treasury address for collecting penalties
    address public treasury;

    /// @notice Total amount staked across all users
    uint256 public totalStaked;

    /// @notice Mapping of user address to stake info
    mapping(address => StakeInfo) public stakes;

    /// @notice Valid lock durations in days
    mapping(uint256 => bool) public validLockDurations;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize the staking contract
     * @param _tkoToken Address of the TKO token
     * @param _treasury Address to receive penalty fees
     * @param _owner Initial owner address
     */
    constructor(
        address _tkoToken,
        address _treasury,
        address _owner
    ) Ownable(_owner) {
        tkoToken = IERC20(_tkoToken);
        treasury = _treasury;

        // Set valid lock durations
        validLockDurations[0] = true;   // No lock
        validLockDurations[30] = true;  // 30 days
        validLockDurations[60] = true;  // 60 days
        validLockDurations[90] = true;  // 90 days
    }

    /*//////////////////////////////////////////////////////////////
                            STAKING LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Stake TKO tokens with optional lock duration
     * @param amount Amount of TKO to stake
     * @param lockDays Number of days to lock (0, 30, 60, or 90)
     * @dev Lock duration cannot be reduced, only extended
     */
    function stake(
        uint256 amount,
        uint256 lockDays
    ) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (!validLockDurations[lockDays]) revert InvalidLockDuration();

        StakeInfo storage userStake = stakes[msg.sender];

        // Check cooldown for existing stakers
        if (userStake.amount > 0) {
            uint256 cooldownEnd = userStake.lastStakeTime + STAKE_COOLDOWN;
            if (block.timestamp < cooldownEnd) {
                revert CooldownActive(cooldownEnd);
            }
        }

        // Calculate new lock end time
        uint256 newLockEnd = lockDays > 0 
            ? block.timestamp + (lockDays * 1 days) 
            : 0;

        // If user already has a lock, only allow extending
        if (userStake.lockEndTime > block.timestamp && newLockEnd < userStake.lockEndTime) {
            newLockEnd = userStake.lockEndTime;
            lockDays = userStake.lockDuration;
        }

        // Update stake info
        userStake.amount += amount;
        userStake.lockEndTime = newLockEnd;
        userStake.lockDuration = lockDays;
        userStake.lastStakeTime = block.timestamp;

        totalStaked += amount;

        // Transfer tokens
        tkoToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount, lockDays, newLockEnd);
    }

    /**
     * @notice Unstake TKO tokens (only after lock expires)
     * @param amount Amount of TKO to unstake
     */
    function unstake(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        StakeInfo storage userStake = stakes[msg.sender];

        if (userStake.amount < amount) revert InsufficientBalance();
        if (userStake.lockEndTime > block.timestamp) {
            revert StakeLocked(userStake.lockEndTime);
        }

        userStake.amount -= amount;
        totalStaked -= amount;

        // Reset lock if fully unstaked
        if (userStake.amount == 0) {
            userStake.lockEndTime = 0;
            userStake.lockDuration = 0;
        }

        tkoToken.safeTransfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    /**
     * @notice Emergency withdraw all staked tokens with penalty
     * @dev Can be called even during lock period, but incurs penalty
     */
    function emergencyWithdraw() external nonReentrant {
        StakeInfo storage userStake = stakes[msg.sender];

        if (userStake.amount == 0) revert NoStakeFound();

        uint256 stakedAmount = userStake.amount;
        uint256 penalty = 0;

        // Apply penalty only if withdrawing during lock period
        if (userStake.lockEndTime > block.timestamp) {
            penalty = (stakedAmount * emergencyPenaltyBps) / 10000;
        }

        uint256 withdrawAmount = stakedAmount - penalty;

        // Reset user stake
        userStake.amount = 0;
        userStake.lockEndTime = 0;
        userStake.lockDuration = 0;

        totalStaked -= stakedAmount;

        // Transfer penalty to treasury
        if (penalty > 0) {
            tkoToken.safeTransfer(treasury, penalty);
        }

        // Transfer remaining to user
        tkoToken.safeTransfer(msg.sender, withdrawAmount);

        emit EmergencyWithdraw(msg.sender, withdrawAmount, penalty);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculate user's current tier based on effective stake
     * @param user Address to check
     * @return tier The user's current tier
     */
    function calculateTier(address user) external view returns (TierLib.Tier tier) {
        uint256 effectiveStake = getEffectiveStake(user);
        return effectiveStake.calculateTier();
    }

    /**
     * @notice Calculate user's effective stake (with lock multiplier)
     * @param user Address to check
     * @return effectiveStake The stake amount multiplied by lock bonus
     */
    function getEffectiveStake(address user) public view returns (uint256 effectiveStake) {
        StakeInfo storage userStake = stakes[user];
        
        if (userStake.amount == 0) return 0;

        uint256 lockMultiplier = TierLib.getLockMultiplier(userStake.lockDuration);
        
        // Calculate effective stake: amount * multiplier / 10000
        effectiveStake = (userStake.amount * lockMultiplier) / 10000;
    }

    /**
     * @notice Get user's stake information
     * @param user Address to check
     * @return amount Staked amount
     * @return lockEndTime Lock expiration timestamp
     * @return lockDuration Lock duration in days
     * @return tier Current tier
     * @return effectiveStake Stake with lock multiplier applied
     */
    function getUserStakeInfo(address user) external view returns (
        uint256 amount,
        uint256 lockEndTime,
        uint256 lockDuration,
        TierLib.Tier tier,
        uint256 effectiveStake
    ) {
        StakeInfo storage userStake = stakes[user];
        amount = userStake.amount;
        lockEndTime = userStake.lockEndTime;
        lockDuration = userStake.lockDuration;
        effectiveStake = getEffectiveStake(user);
        tier = effectiveStake.calculateTier();
    }

    /**
     * @notice Check if user's stake is currently locked
     * @param user Address to check
     * @return isLocked True if stake is locked
     * @return unlockTime Timestamp when stake unlocks (0 if not locked)
     */
    function isStakeLocked(address user) external view returns (
        bool isLocked,
        uint256 unlockTime
    ) {
        StakeInfo storage userStake = stakes[user];
        unlockTime = userStake.lockEndTime;
        isLocked = unlockTime > block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Update emergency withdrawal penalty
     * @param newPenaltyBps New penalty in basis points (max 5000 = 50%)
     */
    function setEmergencyPenalty(uint256 newPenaltyBps) external onlyOwner {
        require(newPenaltyBps <= 5000, "Penalty too high");
        
        emit EmergencyPenaltyUpdated(emergencyPenaltyBps, newPenaltyBps);
        emergencyPenaltyBps = newPenaltyBps;
    }

    /**
     * @notice Update treasury address
     * @param newTreasury New treasury address
     */
    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid treasury");
        treasury = newTreasury;
    }

    /**
     * @notice Pause staking operations
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause staking operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
