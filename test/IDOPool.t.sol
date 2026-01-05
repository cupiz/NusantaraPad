// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {MockTKO} from "../src/mocks/MockTKO.sol";
import {TKOStaking} from "../src/staking/TKOStaking.sol";
import {IDOPool} from "../src/ido/IDOPool.sol";
import {IDOFactory} from "../src/ido/IDOFactory.sol";
import {TierLib} from "../src/libraries/TierLib.sol";

/**
 * @title IDOPoolTest
 * @notice Comprehensive tests for IDOPool and IDOFactory contracts
 */
contract IDOPoolTest is Test {
    MockTKO public tko;
    MockTKO public saleToken;
    TKOStaking public staking;
    IDOFactory public factory;
    IDOPool public pool;

    address public owner = makeAddr("owner");
    address public treasury = makeAddr("treasury");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 constant INITIAL_TKO = 100_000 ether;
    uint256 constant SALE_TOKENS = 1_000_000 ether;

    IDOPool.PoolConfig defaultConfig;
    IDOPool.VestingConfig defaultVesting;

    function setUp() public {
        vm.startPrank(owner);

        // Deploy tokens
        tko = new MockTKO();
        saleToken = new MockTKO();

        // Deploy staking
        staking = new TKOStaking(address(tko), treasury, owner);

        // Deploy factory
        factory = new IDOFactory(address(staking), owner);

        vm.stopPrank();

        // Setup default pool config
        defaultConfig = IDOPool.PoolConfig({
            saleToken: address(saleToken),
            paymentToken: address(0), // BNB
            tokenPrice: 0.001 ether, // 1 token = 0.001 BNB
            softCap: 1 ether,
            hardCap: 100 ether,
            minPurchase: 0.1 ether,
            maxPurchase: 1 ether,
            startTime: block.timestamp + 1 days,
            endTime: block.timestamp + 8 days,
            requireWhitelist: false
        });

        // 20% TGE, 30 day cliff, 8 months vesting, monthly releases
        defaultVesting = IDOPool.VestingConfig({
            tgePercentage: 2000, // 20%
            cliffDuration: 30 days,
            vestingDuration: 240 days, // 8 months
            slicePeriod: 30 days
        });

        // Create pool
        vm.prank(owner);
        address poolAddress = factory.createPool(
            defaultConfig,
            defaultVesting,
            keccak256("test-pool-1")
        );
        pool = IDOPool(payable(poolAddress));

        // Setup users
        tko.mint(alice, INITIAL_TKO);
        tko.mint(bob, INITIAL_TKO);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        // Alice stakes for Silver tier
        vm.startPrank(alice);
        tko.approve(address(staking), type(uint256).max);
        staking.stake(2000 ether, 0); // Silver tier
        vm.stopPrank();

        // Bob stakes for Gold tier
        vm.startPrank(bob);
        tko.approve(address(staking), type(uint256).max);
        staking.stake(10000 ether, 0); // Gold tier
        vm.stopPrank();

        // Deposit sale tokens to pool
        saleToken.mint(owner, SALE_TOKENS);
        vm.startPrank(owner);
        saleToken.approve(address(pool), SALE_TOKENS);
        pool.depositTokens(SALE_TOKENS);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        FACTORY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CreatePool() public {
        assertEq(factory.getPoolCount(), 1);
        assertTrue(factory.isPool(address(pool)));
    }

    function test_ComputePoolAddress() public {
        bytes32 salt = keccak256("test-pool-2");
        
        address predicted = factory.computePoolAddress(
            defaultConfig,
            defaultVesting,
            salt
        );

        vm.prank(owner);
        address actual = factory.createPool(defaultConfig, defaultVesting, salt);

        assertEq(predicted, actual);
    }

    /*//////////////////////////////////////////////////////////////
                       PARTICIPATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ParticipateWithBNB() public {
        // Warp to sale start
        vm.warp(defaultConfig.startTime);

        vm.prank(alice);
        pool.participate{value: 1 ether}(0, new bytes32[](0));

        (uint256 maxAlloc, uint256 contributed, ) = pool.getUserAllocation(alice);
        
        assertEq(contributed, 1 ether);
        // Silver tier = 1x allocation = 1 ether max
        assertEq(maxAlloc, 1 ether);
    }

    function test_GoldTierGetsTripleAllocation() public {
        vm.warp(defaultConfig.startTime);

        (uint256 maxAlloc, , ) = pool.getUserAllocation(bob);
        
        // Gold tier = 3x allocation = 3 ether max
        assertEq(maxAlloc, 3 ether);
    }

    function test_RevertBeforeSaleStart() public {
        vm.prank(alice);
        vm.expectRevert(IDOPool.SaleNotActive.selector);
        pool.participate{value: 1 ether}(0, new bytes32[](0));
    }

    function test_RevertExceedsMaxPurchase() public {
        vm.warp(defaultConfig.startTime);

        vm.prank(alice);
        vm.expectRevert(IDOPool.ExceedsMaxPurchase.selector);
        pool.participate{value: 2 ether}(0, new bytes32[](0)); // Silver max = 1 ether
    }

    /*//////////////////////////////////////////////////////////////
                          VESTING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ClaimTGE() public {
        // Participate (1 ether meets soft cap)
        vm.warp(defaultConfig.startTime);
        vm.prank(alice);
        pool.participate{value: 1 ether}(0, new bytes32[](0));

        // End sale and finalize
        vm.warp(defaultConfig.endTime + 1);
        vm.prank(owner);
        pool.finalize();

        // Claim TGE (20%)
        uint256 tokenAllocation = (1 ether * 1e18) / defaultConfig.tokenPrice;
        uint256 expectedTGE = (tokenAllocation * 2000) / 10000; // 20%

        vm.prank(alice);
        pool.claim();

        assertEq(saleToken.balanceOf(alice), expectedTGE);
    }

    function test_ClaimAfterVesting() public {
        // Participate
        vm.warp(defaultConfig.startTime);
        vm.prank(alice);
        pool.participate{value: 1 ether}(0, new bytes32[](0));

        // Finalize
        vm.warp(defaultConfig.endTime + 1);
        vm.prank(owner);
        pool.finalize();

        // Warp past full vesting period
        vm.warp(block.timestamp + 30 days + 240 days + 1);

        vm.prank(alice);
        pool.claim();

        // Should have 100% of allocation
        uint256 tokenAllocation = (1 ether * 1e18) / defaultConfig.tokenPrice;
        assertEq(saleToken.balanceOf(alice), tokenAllocation);
    }

    /*//////////////////////////////////////////////////////////////
                           REFUND TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RefundIfSoftCapNotMet() public {
        // Participate with less than soft cap (soft cap = 1 ether)
        vm.warp(defaultConfig.startTime);
        vm.prank(alice);
        pool.participate{value: 0.5 ether}(0, new bytes32[](0));

        uint256 balanceBefore = alice.balance;

        // End and finalize (soft cap not met)
        vm.warp(defaultConfig.endTime + 1);
        vm.prank(owner);
        pool.finalize();

        // Request refund
        vm.prank(alice);
        pool.refund();

        assertEq(alice.balance - balanceBefore, 0.5 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        POOL STATUS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetPoolStatus() public {
        vm.warp(defaultConfig.startTime);

        (bool isActive, bool isFilled, uint256 progress) = pool.getPoolStatus();

        assertTrue(isActive);
        assertFalse(isFilled);
        assertEq(progress, 0);

        // Participate to fill
        vm.prank(bob);
        pool.participate{value: 3 ether}(0, new bytes32[](0));

        (, , progress) = pool.getPoolStatus();
        assertEq(progress, 300); // 3/100 = 3%
    }
}
