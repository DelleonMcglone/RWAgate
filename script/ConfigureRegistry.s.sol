// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {ComplianceRegistry} from "../src/lib/ComplianceRegistry.sol";

/// @title ConfigureRegistry
/// @notice Post-deploy script to seed the whitelist with test addresses.
contract ConfigureRegistry is Script {
    function run() external {
        uint256 deployerPk = vm.envUint("PRIVATE_KEY");
        address registryAddr = vm.envAddress("REGISTRY_ADDRESS");

        ComplianceRegistry registry = ComplianceRegistry(registryAddr);

        vm.startBroadcast(deployerPk);

        // Seed test addresses (permanent whitelist — expiry 0)
        address[] memory testAddrs = new address[](3);
        testAddrs[0] = vm.envAddress("TEST_ADDR_1");
        testAddrs[1] = vm.envAddress("TEST_ADDR_2");
        testAddrs[2] = vm.envAddress("TEST_ADDR_3");

        uint256[] memory expiries = new uint256[](3);
        // All permanent (expiry = 0)

        registry.batchAddToWhitelist(testAddrs, expiries);

        console.log("Whitelisted %d addresses", testAddrs.length);

        vm.stopBroadcast();
    }
}
