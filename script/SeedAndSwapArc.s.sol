// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";

interface IERC20 {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @title SeedAndSwapArc
/// @notice Adds USDC/EURC liquidity to the RWAGate-gated pool and executes a test swap,
///         proving the hook permits compliant (whitelisted-router) flow on Arc Testnet.
contract SeedAndSwapArc is Script {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    address constant USDC = 0x3600000000000000000000000000000000000000;
    address constant EURC = 0x89B50855Aa3bE2F677cD6303Cec089B5F319D72a;

    function run() external {
        IPoolManager manager = IPoolManager(vm.envAddress("POOL_MANAGER"));
        address hook = vm.envAddress("HOOK");
        PoolSwapTest swapRouter = PoolSwapTest(vm.envAddress("SWAP_ROUTER"));
        PoolModifyLiquidityTest lpRouter = PoolModifyLiquidityTest(vm.envAddress("LP_ROUTER"));

        (Currency c0, Currency c1) = _sortCurrencies(USDC, EURC);
        PoolKey memory key = PoolKey(c0, c1, 3000, 60, IHooks(hook));

        vm.startBroadcast();

        // Approve both routers to pull USDC and EURC from the deployer.
        IERC20(USDC).approve(address(lpRouter), type(uint256).max);
        IERC20(EURC).approve(address(lpRouter), type(uint256).max);
        IERC20(USDC).approve(address(swapRouter), type(uint256).max);
        IERC20(EURC).approve(address(swapRouter), type(uint256).max);

        // Add liquidity in the ±120 tick band around 1:1.
        // L = 1e9 over this band needs ~6 base units * 1e6 ≈ ~6 USDC and ~6 EURC (6-decimal tokens).
        IPoolManager.ModifyLiquidityParams memory lp = IPoolManager.ModifyLiquidityParams({
            tickLower: -120,
            tickUpper: 120,
            liquidityDelta: 1e9,
            salt: bytes32(0)
        });
        lpRouter.modifyLiquidity(key, lp, "");
        console.log("Liquidity added (USDC/EURC)");

        // Execute a small swap: 0.1 USDC (exact-in), token0 -> token1.
        bool zeroForOne = true; // USDC is currency0 (lower address)
        IPoolManager.SwapParams memory sp = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -100_000, // 0.1 USDC exact input (6 decimals)
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        PoolSwapTest.TestSettings memory ts = PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});

        (uint160 sqrtBefore,,,) = manager.getSlot0(key.toId());
        BalanceDelta delta = swapRouter.swap(key, sp, ts, "");
        (uint160 sqrtAfter,,,) = manager.getSlot0(key.toId());

        vm.stopBroadcast();

        console.log("Swap executed through RWAGate-gated pool");
        console.log("  amount0 delta:", int256(delta.amount0()));
        console.log("  amount1 delta:", int256(delta.amount1()));
        console.log("  sqrtPriceX96 before:", uint256(sqrtBefore));
        console.log("  sqrtPriceX96 after: ", uint256(sqrtAfter));
    }

    function _sortCurrencies(address a, address b) internal pure returns (Currency, Currency) {
        if (a < b) return (Currency.wrap(a), Currency.wrap(b));
        return (Currency.wrap(b), Currency.wrap(a));
    }
}
