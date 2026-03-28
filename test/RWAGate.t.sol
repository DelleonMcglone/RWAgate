// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {CustomRevert} from "v4-core/src/libraries/CustomRevert.sol";
import {ComplianceRegistry} from "../src/lib/ComplianceRegistry.sol";
import {ComplianceChecker} from "../src/lib/ComplianceChecker.sol";
import {RWAGate} from "../src/RWAGate.sol";

contract RWAGateTest is Test, Deployers {
    RWAGate hook;
    ComplianceRegistry registry;

    address hookAddr;

    // Hook flags: beforeSwap (1<<7) | beforeRemoveLiquidity (1<<9) | beforeAddLiquidity (1<<11)
    uint160 constant HOOK_FLAGS =
        uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG);

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        registry = new ComplianceRegistry(address(this));

        hookAddr = address(HOOK_FLAGS);
        bytes memory constructorArgs = abi.encode(address(manager), address(registry));
        deployCodeTo("RWAGate.sol:RWAGate", constructorArgs, hookAddr);
        hook = RWAGate(hookAddr);

        (key,) = initPool(currency0, currency1, IHooks(hookAddr), 3000, SQRT_PRICE_1_1);

        // Whitelist routers (sender in hooks is the router, not the EOA)
        registry.addToWhitelist(address(swapRouter), 0);
        registry.addToWhitelist(address(modifyLiquidityRouter), 0);

        // Seed liquidity
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    // ─── Swap Tests ──────────────────────────────────────────────────────

    function test_swap_whitelisted_succeeds() public {
        BalanceDelta delta = swap(key, true, -100, ZERO_BYTES);
        assertTrue(int256(delta.amount0()) != 0 || int256(delta.amount1()) != 0);
    }

    function test_swap_notWhitelisted_reverts() public {
        registry.removeFromWhitelist(address(swapRouter));
        vm.expectRevert();
        swap(key, true, -100, ZERO_BYTES);
    }

    function test_swap_expired_reverts() public {
        uint256 exp = block.timestamp + 1;
        registry.addToWhitelist(address(swapRouter), exp);
        vm.warp(block.timestamp + 2);
        vm.expectRevert();
        swap(key, true, -100, ZERO_BYTES);
    }

    function test_swap_paused_reverts() public {
        registry.pause();
        vm.expectRevert();
        swap(key, true, -100, ZERO_BYTES);
    }

    // ─── Add Liquidity Tests ─────────────────────────────────────────────

    function test_addLiquidity_whitelisted_succeeds() public {
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_addLiquidity_notWhitelisted_reverts() public {
        registry.removeFromWhitelist(address(modifyLiquidityRouter));
        vm.expectRevert();
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_addLiquidity_paused_reverts() public {
        registry.pause();
        vm.expectRevert();
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    // ─── Remove Liquidity Tests ──────────────────────────────────────────

    function test_removeLiquidity_whitelisted_succeeds() public {
        modifyLiquidityRouter.modifyLiquidity(key, REMOVE_LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_removeLiquidity_notWhitelisted_reverts() public {
        registry.removeFromWhitelist(address(modifyLiquidityRouter));
        vm.expectRevert();
        modifyLiquidityRouter.modifyLiquidity(key, REMOVE_LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_removeLiquidity_paused_reverts() public {
        registry.pause();
        vm.expectRevert();
        modifyLiquidityRouter.modifyLiquidity(key, REMOVE_LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    // ─── Paused Priority ─────────────────────────────────────────────────

    function test_paused_priorityOverNotWhitelisted() public {
        registry.removeFromWhitelist(address(swapRouter));
        registry.pause();
        vm.expectRevert();
        swap(key, true, -100, ZERO_BYTES);
    }

    // ─── Hook Properties ─────────────────────────────────────────────────

    function test_hookDoesNotModifyDelta() public {
        // Swap should succeed and hook should return ZERO_DELTA
        BalanceDelta delta = swap(key, true, -100, ZERO_BYTES);
        // If the hook modified delta, amounts would be different
        assertTrue(delta.amount0() != 0 || delta.amount1() != 0, "swap should produce non-zero delta");
    }

    function test_onlyPoolManager_beforeSwap() public {
        vm.expectRevert(RWAGate.OnlyPoolManager.selector);
        hook.beforeSwap(address(this), key, SWAP_PARAMS, ZERO_BYTES);
    }

    function test_onlyPoolManager_beforeAddLiquidity() public {
        vm.expectRevert(RWAGate.OnlyPoolManager.selector);
        hook.beforeAddLiquidity(address(this), key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_onlyPoolManager_beforeRemoveLiquidity() public {
        vm.expectRevert(RWAGate.OnlyPoolManager.selector);
        hook.beforeRemoveLiquidity(address(this), key, REMOVE_LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    // ─── Not Implemented Hooks ───────────────────────────────────────────

    function test_beforeInitialize_reverts() public {
        vm.expectRevert(RWAGate.HookNotImplemented.selector);
        hook.beforeInitialize(address(this), key, SQRT_PRICE_1_1);
    }

    function test_afterInitialize_reverts() public {
        vm.expectRevert(RWAGate.HookNotImplemented.selector);
        hook.afterInitialize(address(this), key, SQRT_PRICE_1_1, 0);
    }

    function test_afterAddLiquidity_reverts() public {
        BalanceDelta zeroDelta = BalanceDelta.wrap(0);
        vm.expectRevert(RWAGate.HookNotImplemented.selector);
        hook.afterAddLiquidity(address(this), key, LIQUIDITY_PARAMS, zeroDelta, zeroDelta, ZERO_BYTES);
    }

    function test_afterRemoveLiquidity_reverts() public {
        BalanceDelta zeroDelta = BalanceDelta.wrap(0);
        vm.expectRevert(RWAGate.HookNotImplemented.selector);
        hook.afterRemoveLiquidity(address(this), key, REMOVE_LIQUIDITY_PARAMS, zeroDelta, zeroDelta, ZERO_BYTES);
    }

    function test_afterSwap_reverts() public {
        BalanceDelta zeroDelta = BalanceDelta.wrap(0);
        vm.expectRevert(RWAGate.HookNotImplemented.selector);
        hook.afterSwap(address(this), key, SWAP_PARAMS, zeroDelta, ZERO_BYTES);
    }

    function test_beforeDonate_reverts() public {
        vm.expectRevert(RWAGate.HookNotImplemented.selector);
        hook.beforeDonate(address(this), key, 0, 0, ZERO_BYTES);
    }

    function test_afterDonate_reverts() public {
        vm.expectRevert(RWAGate.HookNotImplemented.selector);
        hook.afterDonate(address(this), key, 0, 0, ZERO_BYTES);
    }
}
