// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {MockTKO} from "../src/mocks/MockTKO.sol";
import {TKOStaking} from "../src/staking/TKOStaking.sol";
import {IDOFactory} from "../src/ido/IDOFactory.sol";

/**
 * @title DeployScript
 * @notice Deployment script for NusantaraPad contracts
 * @dev Run with: forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast
 */
contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address treasury = vm.envOr("TREASURY", deployer);
        
        // For testnet, use MockTKO. For mainnet, use real TKO address
        address tkoAddress = vm.envOr(
            "TKO_ADDRESS",
            address(0) // Will deploy MockTKO if not set
        );

        console2.log("Deployer:", deployer);
        console2.log("Treasury:", treasury);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy MockTKO if needed (testnet only)
        MockTKO mockTko;
        if (tkoAddress == address(0)) {
            mockTko = new MockTKO();
            tkoAddress = address(mockTko);
            console2.log("MockTKO deployed at:", tkoAddress);

            // Mint some tokens for testing
            mockTko.mint(deployer, 1_000_000 ether);
        }

        // Deploy Staking
        TKOStaking staking = new TKOStaking(tkoAddress, treasury, deployer);
        console2.log("TKOStaking deployed at:", address(staking));

        // Deploy Factory
        IDOFactory factory = new IDOFactory(address(staking), deployer);
        console2.log("IDOFactory deployed at:", address(factory));

        vm.stopBroadcast();

        // Log deployment summary
        console2.log("\n=== Deployment Summary ===");
        console2.log("TKO Token:", tkoAddress);
        console2.log("Staking:", address(staking));
        console2.log("Factory:", address(factory));
    }
}
