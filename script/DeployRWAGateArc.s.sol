// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";
import {ComplianceRegistry} from "../src/lib/ComplianceRegistry.sol";
import {RWAGate} from "../src/RWAGate.sol";

/// @title DeployRWAGateArc
/// @notice Deploys the full RWAGate stack to Arc Testnet (chain 5042002).
///         Arc has no canonical Uniswap v4 deployment, so this script also deploys
///         a fresh PoolManager and the PoolSwapTest / PoolModifyLiquidityTest routers,
///         then initializes the USDC/EURC pool gated by the RWAGate hook.
contract DeployRWAGateArc is Script {
    // ─── Arc Testnet Constants ───────────────────────────────────────────
    // USDC is the native gas token on Arc; 0x3600..0000 is its ERC-20 interface (6dp).
    address constant USDC = 0x3600000000000000000000000000000000000000;
    address constant EURC = 0x89B50855Aa3bE2F677cD6303Cec089B5F319D72a;

    // NOTE: CREATE2_FACTORY (0x4e59b448..., present on Arc and used by Foundry for
    // `new X{salt:}`) is inherited from forge-std's CommonBase.

    // Hook flags: beforeSwap | beforeAddLiquidity | beforeRemoveLiquidity
    uint160 constant HOOK_FLAGS =
        uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG);

    function run() external {
        address deployer = vm.envAddress("DEPLOYER");

        vm.startBroadcast();

        // 1. Deploy a v4 PoolManager (Arc has none). Deployer is the protocol-fee owner.
        PoolManager manager = new PoolManager(deployer);
        console.log("PoolManager deployed at:       ", address(manager));

        // 2. Deploy ComplianceRegistry with deployer as operator.
        ComplianceRegistry registry = new ComplianceRegistry(deployer);
        console.log("ComplianceRegistry deployed at:", address(registry));

        // 3. Mine a CREATE2 salt so the hook address encodes the correct permission flags.
        bytes memory creationCode =
            abi.encodePacked(type(RWAGate).creationCode, abi.encode(address(manager), address(registry)));
        bytes32 salt = _mineSalt(CREATE2_FACTORY, creationCode, HOOK_FLAGS);

        // 4. Deploy RWAGate via CREATE2.
        RWAGate hook = new RWAGate{salt: salt}(manager, registry);
        require(uint160(address(hook)) & Hooks.ALL_HOOK_MASK == HOOK_FLAGS, "Hook address flag mismatch");
        console.log("RWAGate deployed at:           ", address(hook));

        // 5. Deploy test routers so the pool can be exercised end-to-end.
        PoolSwapTest swapRouter = new PoolSwapTest(manager);
        PoolModifyLiquidityTest lpRouter = new PoolModifyLiquidityTest(manager);
        console.log("PoolSwapTest deployed at:      ", address(swapRouter));
        console.log("PoolModifyLiquidityTest at:    ", address(lpRouter));

        // 6. Whitelist the routers (the hook sees the router as `sender`, not the EOA)
        //    plus the deployer EOA for direct interactions. Permanent (expiry 0).
        registry.addToWhitelist(address(swapRouter), 0);
        registry.addToWhitelist(address(lpRouter), 0);
        registry.addToWhitelist(deployer, 0);

        // 7. Initialize the USDC/EURC pool at 1:1, fee 0.30%, tickSpacing 60.
        (Currency c0, Currency c1) = _sortCurrencies(USDC, EURC);
        PoolKey memory key = PoolKey(c0, c1, 3000, 60, IHooks(address(hook)));
        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(0);
        manager.initialize(key, sqrtPriceX96);
        console.log("USDC/EURC pool initialized");

        vm.stopBroadcast();

        console.log("========================================");
        console.log("RWAGate Deployment Summary (Arc Testnet 5042002)");
        console.log("========================================");
        console.log("PoolManager:           ", address(manager));
        console.log("ComplianceRegistry:    ", address(registry));
        console.log("RWAGate (HOOK):        ", address(hook));
        console.log("PoolSwapTest:          ", address(swapRouter));
        console.log("PoolModifyLiquidityTest:", address(lpRouter));
        console.log("currency0:             ", Currency.unwrap(c0));
        console.log("currency1:             ", Currency.unwrap(c1));
        console.log("Operator/Deployer:     ", deployer);
    }

    /// @dev Mine a CREATE2 salt producing an address whose low bits match the hook flags.
    function _mineSalt(address deployer, bytes memory creationCode, uint160 flags) internal pure returns (bytes32) {
        bytes32 initCodeHash = keccak256(creationCode);
        for (uint256 i; i < 200_000; ++i) {
            bytes32 salt = bytes32(i);
            address predicted =
                address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, initCodeHash)))));
            if (uint160(predicted) & Hooks.ALL_HOOK_MASK == flags) {
                return salt;
            }
        }
        revert("Salt not found within 200k iterations");
    }

    function _sortCurrencies(address a, address b) internal pure returns (Currency, Currency) {
        if (a < b) return (Currency.wrap(a), Currency.wrap(b));
        return (Currency.wrap(b), Currency.wrap(a));
    }
}
