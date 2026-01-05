// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {MockTKO} from "../src/mocks/MockTKO.sol";
import {TKOStaking} from "../src/staking/TKOStaking.sol";
import {TierLib} from "../src/libraries/TierLib.sol";

/**
 * @title TKOStakingTest
 * @notice Comprehensive tests for TKOStaking contract
 */
contract TKOStakingTest is Test {
    MockTKO public tko;
    TKOStaking public staking;

    address public owner = makeAddr("owner");
    address public treasury = makeAddr("treasury");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 constant INITIAL_BALANCE = 100_000 ether;

    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy contracts
        tko = new MockTKO();
        staking = new TKOStaking(address(tko), treasury, owner);

        vm.stopPrank();

        // Mint tokens to users
        tko.mint(alice, INITIAL_BALANCE);
        tko.mint(bob, INITIAL_BALANCE);

        // Approve staking contract
        vm.prank(alice);
        tko.approve(address(staking), type(uint256).max);

        vm.prank(bob);
        tko.approve(address(staking), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                            STAKING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StakeWithoutLock() public {
        uint256 stakeAmount = 1000 ether;

        vm.prank(alice);
        staking.stake(stakeAmount, 0);

        (
            uint256 amount,
            uint256 lockEndTime,
            uint256 lockDuration,
            TierLib.Tier tier,
            uint256 effectiveStake
        ) = staking.getUserStakeInfo(alice);

        assertEq(amount, stakeAmount);
        assertEq(lockEndTime, 0);
        assertEq(lockDuration, 0);
        assertEq(uint8(tier), uint8(TierLib.Tier.Bronze));
        assertEq(effectiveStake, stakeAmount); // 1.0x multiplier
    }

    function test_StakeWith30DayLock() public {
        uint256 stakeAmount = 2000 ether;

        vm.prank(alice);
        staking.stake(stakeAmount, 30);

        uint256 effectiveStake = staking.getEffectiveStake(alice);
        
        // 2000 * 1.2 = 2400
        assertEq(effectiveStake, 2400 ether);
        
        TierLib.Tier tier = staking.calculateTier(alice);
        assertEq(uint8(tier), uint8(TierLib.Tier.Silver));
    }

    function test_StakeFor90DaysReachesPlatinum() public {
        uint256 stakeAmount = 25_000 ether;

        vm.prank(alice);
        staking.stake(stakeAmount, 90);

        uint256 effectiveStake = staking.getEffectiveStake(alice);
        
        // 25000 * 2.0 = 50000
        assertEq(effectiveStake, 50_000 ether);
        
        TierLib.Tier tier = staking.calculateTier(alice);
        assertEq(uint8(tier), uint8(TierLib.Tier.Platinum));
    }

    /*//////////////////////////////////////////////////////////////
                           UNSTAKING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_UnstakeAfterLockExpires() public {
        uint256 stakeAmount = 1000 ether;

        vm.prank(alice);
        staking.stake(stakeAmount, 30);

        // Warp past lock period
        vm.warp(block.timestamp + 31 days);

        uint256 balanceBefore = tko.balanceOf(alice);

        vm.prank(alice);
        staking.unstake(stakeAmount);

        uint256 balanceAfter = tko.balanceOf(alice);
        assertEq(balanceAfter - balanceBefore, stakeAmount);
    }

    function test_RevertUnstakeDuringLock() public {
        uint256 stakeAmount = 1000 ether;

        vm.prank(alice);
        staking.stake(stakeAmount, 30);

        vm.prank(alice);
        vm.expectRevert();
        staking.unstake(stakeAmount);
    }

    /*//////////////////////////////////////////////////////////////
                      EMERGENCY WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_EmergencyWithdrawDuringLock() public {
        uint256 stakeAmount = 1000 ether;

        vm.prank(alice);
        staking.stake(stakeAmount, 30);

        uint256 balanceBefore = tko.balanceOf(alice);

        vm.prank(alice);
        staking.emergencyWithdraw();

        uint256 balanceAfter = tko.balanceOf(alice);
        uint256 expectedPenalty = (stakeAmount * 1000) / 10_000; // 10%
        
        assertEq(balanceAfter - balanceBefore, stakeAmount - expectedPenalty);
        assertEq(tko.balanceOf(treasury), expectedPenalty);
    }

    function test_EmergencyWithdrawNoPenaltyAfterLock() public {
        uint256 stakeAmount = 1000 ether;

        vm.prank(alice);
        staking.stake(stakeAmount, 30);

        // Warp past lock
        vm.warp(block.timestamp + 31 days);

        uint256 balanceBefore = tko.balanceOf(alice);

        vm.prank(alice);
        staking.emergencyWithdraw();

        uint256 balanceAfter = tko.balanceOf(alice);
        
        // No penalty after lock expires
        assertEq(balanceAfter - balanceBefore, stakeAmount);
    }

    /*//////////////////////////////////////////////////////////////
                          TIER CALCULATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_TierNone() public {
        vm.prank(alice);
        staking.stake(499 ether, 0);
        assertEq(uint8(staking.calculateTier(alice)), uint8(TierLib.Tier.None));
    }

    function test_TierBronze() public {
        vm.prank(alice);
        staking.stake(500 ether, 0);
        assertEq(uint8(staking.calculateTier(alice)), uint8(TierLib.Tier.Bronze));
    }

    function test_TierSilver() public {
        vm.prank(alice);
        staking.stake(2000 ether, 0);
        assertEq(uint8(staking.calculateTier(alice)), uint8(TierLib.Tier.Silver));
    }

    function test_TierGold() public {
        vm.prank(alice);
        staking.stake(10000 ether, 0);
        assertEq(uint8(staking.calculateTier(alice)), uint8(TierLib.Tier.Gold));
    }

    function test_TierPlatinum() public {
        vm.prank(alice);
        staking.stake(50000 ether, 0);
        assertEq(uint8(staking.calculateTier(alice)), uint8(TierLib.Tier.Platinum));
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Pause() public {
        vm.prank(owner);
        staking.pause();

        vm.prank(alice);
        vm.expectRevert();
        staking.stake(1000 ether, 0);
    }

    function test_SetEmergencyPenalty() public {
        vm.prank(owner);
        staking.setEmergencyPenalty(2000); // 20%

        assertEq(staking.emergencyPenaltyBps(), 2000);
    }

    function test_RevertSetPenaltyTooHigh() public {
        vm.prank(owner);
        vm.expectRevert("Penalty too high");
        staking.setEmergencyPenalty(5001); // > 50%
    }
}
