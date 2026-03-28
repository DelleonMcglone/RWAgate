// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {ComplianceRegistry} from "../src/lib/ComplianceRegistry.sol";
import {ComplianceChecker} from "../src/lib/ComplianceChecker.sol";

/// @dev Wrapper contract to make checkCompliance an external call so vm.expectRevert works.
contract CheckerHarness {
    using ComplianceChecker for ComplianceRegistry;

    ComplianceRegistry public registry;

    constructor(ComplianceRegistry _registry) {
        registry = _registry;
    }

    function check(address sender) external view {
        registry.checkCompliance(sender);
    }
}

contract ComplianceCheckerTest is Test {
    ComplianceRegistry registry;
    CheckerHarness harness;
    address operator = address(this);
    address alice = makeAddr("alice");

    function setUp() public {
        registry = new ComplianceRegistry(operator);
        harness = new CheckerHarness(registry);
    }

    function test_checkCompliance_passes() public {
        registry.addToWhitelist(alice, 0);
        harness.check(alice); // should not revert
    }

    function test_checkCompliance_passesWithValidExpiry() public {
        registry.addToWhitelist(alice, block.timestamp + 1 days);
        harness.check(alice);
    }

    function test_checkCompliance_revertsNotWhitelisted() public {
        vm.expectRevert(abi.encodeWithSelector(ComplianceChecker.NotWhitelisted.selector, alice));
        harness.check(alice);
    }

    function test_checkCompliance_revertsWhitelistExpired() public {
        uint256 exp = block.timestamp + 1;
        registry.addToWhitelist(alice, exp);
        vm.warp(block.timestamp + 2);
        vm.expectRevert(abi.encodeWithSelector(ComplianceChecker.WhitelistExpired.selector, alice, exp));
        harness.check(alice);
    }

    function test_checkCompliance_revertsPoolPaused() public {
        registry.pause();
        vm.expectRevert(ComplianceChecker.PoolPaused.selector);
        harness.check(alice);
    }

    function test_checkCompliance_pausedTakesPriorityOverNotWhitelisted() public {
        registry.pause();
        vm.expectRevert(ComplianceChecker.PoolPaused.selector);
        harness.check(alice);
    }

    function test_checkCompliance_pausedTakesPriorityOverExpired() public {
        uint256 exp = block.timestamp + 1;
        registry.addToWhitelist(alice, exp);
        vm.warp(block.timestamp + 2);
        registry.pause();
        vm.expectRevert(ComplianceChecker.PoolPaused.selector);
        harness.check(alice);
    }
}
