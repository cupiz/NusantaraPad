// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {MockTKO} from "../src/mocks/MockTKO.sol";
import {TKOStaking} from "../src/staking/TKOStaking.sol";
import {IDOFactory} from "../src/ido/IDOFactory.sol";

/**
 * @title DeployLocalScript
 * @notice Simplified deployment script for local Anvil testing
 * @dev Run with: forge script script/DeployLocal.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
 */
contract DeployLocalScript is Script {
    // Anvil default account #0
    address constant DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    
    function run() external {
        vm.startBroadcast();

        // Deploy MockTKO
        MockTKO mockTko = new MockTKO();
        console2.log("MockTKO deployed at:", address(mockTko));

        // Mint tokens to deployer and test accounts
        mockTko.mint(DEPLOYER, 1_000_000 ether);
        mockTko.mint(0x70997970C51812dc3A010C7d01b50e0d17dc79C8, 100_000 ether); // Account #1
        mockTko.mint(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC, 100_000 ether); // Account #2
        console2.log("Minted TKO to test accounts");

        // Deploy Staking
        TKOStaking staking = new TKOStaking(address(mockTko), DEPLOYER, DEPLOYER);
        console2.log("TKOStaking deployed at:", address(staking));

        // Deploy Factory
        IDOFactory factory = new IDOFactory(address(staking), DEPLOYER);
        console2.log("IDOFactory deployed at:", address(factory));

        vm.stopBroadcast();

        // Log deployment summary for frontend config
        console2.log("\n========================================");
        console2.log("COPY THESE TO frontend/src/config/wagmi.ts");
        console2.log("========================================");
        console2.log("TKO:", address(mockTko));
        console2.log("TKOStaking:", address(staking));
        console2.log("IDOFactory:", address(factory));
        console2.log("========================================");
    }
}
