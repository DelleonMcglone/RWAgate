// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {ComplianceRegistry} from "../src/lib/ComplianceRegistry.sol";

contract ComplianceRegistryTest is Test {
    ComplianceRegistry registry;
    address operator = address(this);
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        registry = new ComplianceRegistry(operator);
    }

    // ─── Constructor ─────────────────────────────────────────────────────

    function test_constructor_setsOperator() public view {
        assertEq(registry.operator(), operator);
    }

    function test_constructor_revertsZeroAddress() public {
        vm.expectRevert(ComplianceRegistry.ZeroAddress.selector);
        new ComplianceRegistry(address(0));
    }

    // ─── addToWhitelist ──────────────────────────────────────────────────

    function test_addToWhitelist_noExpiry() public {
        registry.addToWhitelist(alice, 0);
        assertTrue(registry.whitelist(alice));
        assertEq(registry.expiry(alice), 0);
    }

    function test_addToWhitelist_withExpiry() public {
        uint256 exp = block.timestamp + 1 days;
        registry.addToWhitelist(alice, exp);
        assertTrue(registry.whitelist(alice));
        assertEq(registry.expiry(alice), exp);
    }

    function test_addToWhitelist_revertsZeroAddress() public {
        vm.expectRevert(ComplianceRegistry.ZeroAddress.selector);
        registry.addToWhitelist(address(0), 0);
    }

    function test_addToWhitelist_revertsExpiryInPast() public {
        vm.warp(1000);
        vm.expectRevert(abi.encodeWithSelector(ComplianceRegistry.ExpiryInPast.selector, 999));
        registry.addToWhitelist(alice, 999);
    }

    function test_addToWhitelist_reAddUpdatesExpiry() public {
        registry.addToWhitelist(alice, 0);
        uint256 newExpiry = block.timestamp + 2 days;
        registry.addToWhitelist(alice, newExpiry);
        assertEq(registry.expiry(alice), newExpiry);
    }

    function test_addToWhitelist_onlyOperator() public {
        vm.prank(alice);
        vm.expectRevert(ComplianceRegistry.OnlyOperator.selector);
        registry.addToWhitelist(bob, 0);
    }

    function test_addToWhitelist_emitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit ComplianceRegistry.Whitelisted(alice, 0);
        registry.addToWhitelist(alice, 0);
    }

    // ─── batchAddToWhitelist ─────────────────────────────────────────────

    function test_batchAddToWhitelist() public {
        address[] memory accounts = new address[](2);
        accounts[0] = alice;
        accounts[1] = bob;
        uint256[] memory expiries = new uint256[](2);
        expiries[0] = 0;
        expiries[1] = block.timestamp + 1 days;

        registry.batchAddToWhitelist(accounts, expiries);
        assertTrue(registry.whitelist(alice));
        assertTrue(registry.whitelist(bob));
    }

    function test_batchAddToWhitelist_lengthMismatch() public {
        address[] memory accounts = new address[](2);
        accounts[0] = alice;
        accounts[1] = bob;
        uint256[] memory expiries = new uint256[](1);

        vm.expectRevert(bytes("length mismatch"));
        registry.batchAddToWhitelist(accounts, expiries);
    }

    function test_batchAddToWhitelist_revertsZeroAddress() public {
        address[] memory accounts = new address[](1);
        accounts[0] = address(0);
        uint256[] memory expiries = new uint256[](1);

        vm.expectRevert(ComplianceRegistry.ZeroAddress.selector);
        registry.batchAddToWhitelist(accounts, expiries);
    }

    function test_batchAddToWhitelist_revertsExpiryInPast() public {
        vm.warp(1000);
        address[] memory accounts = new address[](1);
        accounts[0] = alice;
        uint256[] memory expiries = new uint256[](1);
        expiries[0] = 999;

        vm.expectRevert(abi.encodeWithSelector(ComplianceRegistry.ExpiryInPast.selector, 999));
        registry.batchAddToWhitelist(accounts, expiries);
    }

    function test_batchAddToWhitelist_onlyOperator() public {
        address[] memory accounts = new address[](0);
        uint256[] memory expiries = new uint256[](0);

        vm.prank(alice);
        vm.expectRevert(ComplianceRegistry.OnlyOperator.selector);
        registry.batchAddToWhitelist(accounts, expiries);
    }

    // ─── removeFromWhitelist ─────────────────────────────────────────────

    function test_removeFromWhitelist() public {
        registry.addToWhitelist(alice, 0);
        registry.removeFromWhitelist(alice);
        assertFalse(registry.whitelist(alice));
        assertEq(registry.expiry(alice), 0);
    }

    function test_removeFromWhitelist_nonExistentIsSilent() public {
        registry.removeFromWhitelist(alice);
        assertFalse(registry.whitelist(alice));
    }

    function test_removeFromWhitelist_onlyOperator() public {
        vm.prank(alice);
        vm.expectRevert(ComplianceRegistry.OnlyOperator.selector);
        registry.removeFromWhitelist(bob);
    }

    // ─── isCompliant ─────────────────────────────────────────────────────

    function test_isCompliant_whitelistedNoExpiry() public {
        registry.addToWhitelist(alice, 0);
        assertTrue(registry.isCompliant(alice));
    }

    function test_isCompliant_whitelistedValidExpiry() public {
        registry.addToWhitelist(alice, block.timestamp + 1 days);
        assertTrue(registry.isCompliant(alice));
    }

    function test_isCompliant_notWhitelisted() public view {
        assertFalse(registry.isCompliant(alice));
    }

    function test_isCompliant_expired() public {
        registry.addToWhitelist(alice, block.timestamp + 1);
        vm.warp(block.timestamp + 2);
        assertFalse(registry.isCompliant(alice));
    }

    function test_isCompliant_expiryExactlyAtTimestamp() public {
        uint256 exp = block.timestamp + 10;
        registry.addToWhitelist(alice, exp);
        vm.warp(exp); // exactly at expiry — should still be compliant (exp < block.timestamp is false)
        assertTrue(registry.isCompliant(alice));
    }

    function test_isCompliant_paused() public {
        registry.addToWhitelist(alice, 0);
        registry.pause();
        assertFalse(registry.isCompliant(alice));
    }

    // ─── Operator Transfer ───────────────────────────────────────────────

    function test_proposeOperator() public {
        registry.proposeOperator(alice);
        assertEq(registry.pendingOperator(), alice);
    }

    function test_proposeOperator_revertsZeroAddress() public {
        vm.expectRevert(ComplianceRegistry.ZeroAddress.selector);
        registry.proposeOperator(address(0));
    }

    function test_proposeOperator_onlyOperator() public {
        vm.prank(alice);
        vm.expectRevert(ComplianceRegistry.OnlyOperator.selector);
        registry.proposeOperator(bob);
    }

    function test_acceptOperator() public {
        registry.proposeOperator(alice);
        vm.prank(alice);
        registry.acceptOperator();
        assertEq(registry.operator(), alice);
        assertEq(registry.pendingOperator(), address(0));
    }

    function test_acceptOperator_revertsNonPending() public {
        registry.proposeOperator(alice);
        vm.prank(bob);
        vm.expectRevert(ComplianceRegistry.OnlyPendingOperator.selector);
        registry.acceptOperator();
    }

    // ─── Pause / Unpause ─────────────────────────────────────────────────

    function test_pause() public {
        registry.pause();
        assertTrue(registry.paused());
    }

    function test_unpause() public {
        registry.pause();
        registry.unpause();
        assertFalse(registry.paused());
    }

    function test_pause_onlyOperator() public {
        vm.prank(alice);
        vm.expectRevert(ComplianceRegistry.OnlyOperator.selector);
        registry.pause();
    }

    function test_unpause_onlyOperator() public {
        registry.pause();
        vm.prank(alice);
        vm.expectRevert(ComplianceRegistry.OnlyOperator.selector);
        registry.unpause();
    }
}
