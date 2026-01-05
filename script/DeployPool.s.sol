// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {MockTKO} from "../src/mocks/MockTKO.sol";
import {IDOFactory} from "../src/ido/IDOFactory.sol";
import {IDOPool} from "../src/ido/IDOPool.sol";
import {IIDOPool} from "../src/interfaces/IIDOPool.sol";
// import {CheckScript} from "./CheckScript.s.sol";

/**
 * @title DeployPoolScript
 * @notice Script to deploy a test IDO pool for "Project Mars" ($MARS)
 * @dev Run after DeployLocal.s.sol
 */
contract DeployPoolScript is Script {
    // Contract addresses from previous deployment (CheckScript will auto-fill if used, but we hardcode for simplicity/Anvil)
    // IMPORTANT: UPDATE THESE IF ANVIL RESTARTED AND ADDRESSES CHANGED
    address constant FACTORY = 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707; 
    
    // Anvil default account #0
    address constant DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function run() external {
        vm.startBroadcast();

        // 1. Deploy Project Token ($MARS)
        MockTKO marsToken = new MockTKO(); // Reuse MockTKO logic for simplicity
        // But let's verify if we can rename it? MockTKO is hardcoded name/symbol.
        // It's okay for testing, but let's just use it as is. Format: 18 decimals.
        console2.log("Project Token ($MARS) deployed at:", address(marsToken));

        // 2. Mint tokens for the pool (e.g. 1,000,000 MARS for sale)
        uint256 saleAmount = 1_000_000 ether;
        marsToken.mint(DEPLOYER, saleAmount);
        
        // 3. Create IDO Pool via Factory
        // Params:
        // - token: address(marsToken)
        // - tokenPrice: 0.001 BNB (1 BNB = 1000 MARS)
        // - startTime: now + 5 minutes
        // - endTime: now + 7 days
        // - softCap: 10 BNB
        // - hardCap: 1000 BNB
        // - minBuy: 0.1 BNB
        // - maxBuy: 10 BNB
        
        uint256 tokenPrice = 0.001 ether; // 1 MARS = 0.001 BNB
        uint256 nowTime = block.timestamp;

        // Configuration
        IDOPool.PoolConfig memory config = IDOPool.PoolConfig({
            saleToken: address(marsToken),
            paymentToken: address(0), // BNB
            tokenPrice: tokenPrice,
            softCap: 10 ether,
            hardCap: 1000 ether,
            minPurchase: 0.1 ether,
            maxPurchase: 10 ether,
            startTime: nowTime + 300, // Starts in 5 mins
            endTime: nowTime + 7 days,
            requireWhitelist: false // Public pool for easier testing
        });

        IDOPool.VestingConfig memory vesting = IDOPool.VestingConfig({
            tgePercentage: 2000, // 20%
            cliffDuration: 30 days,
            vestingDuration: 150 days,
            slicePeriod: 30 days
        });

        bytes32 salt = keccak256(abi.encodePacked(block.timestamp)); // Random salt

        address poolAddress = IDOFactory(FACTORY).createPool(
            config,
            vesting,
            salt
        );
        
        console2.log("IDO Pool created at:", poolAddress);

        // 4. Fund the pool with tokens
        marsToken.transfer(poolAddress, saleAmount);
        console2.log("Pool funded with 1,000,000 tokens");

        vm.stopBroadcast();
        
        console2.log("\n=== IDO Pool Ready ===");
        console2.log("Pool Address:", poolAddress);
        console2.log("Token Address:", address(marsToken));
    }
}
