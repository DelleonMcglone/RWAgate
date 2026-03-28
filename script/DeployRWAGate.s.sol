// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {ComplianceRegistry} from "../src/lib/ComplianceRegistry.sol";
import {RWAGate} from "../src/RWAGate.sol";

/// @title DeployRWAGate
/// @notice Deploys ComplianceRegistry + RWAGate via CREATE2 and initializes pools on Base Sepolia.
contract DeployRWAGate is Script {
    // ─── Base Sepolia Constants ──────────────────────────────────────────
    IPoolManager constant POOL_MANAGER = IPoolManager(0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408);
    address constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address constant EURC = 0x808456652fdb597867f38412077A9182bf77359F;
    address constant CB_BCT = 0xcbB7C0006F23900c38EB856149F799620fcb8A4a;

    // Hook flags: beforeSwap | beforeAddLiquidity | beforeRemoveLiquidity
    uint160 constant HOOK_FLAGS =
        uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG);

    function run() external {
        uint256 deployerPk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        // 1. Deploy ComplianceRegistry
        ComplianceRegistry registry = new ComplianceRegistry(deployer);
        console.log("ComplianceRegistry deployed at:", address(registry));

        // 2. Mine CREATE2 salt for hook address with correct flags
        bytes memory creationCode = abi.encodePacked(
            type(RWAGate).creationCode,
            abi.encode(address(POOL_MANAGER), address(registry))
        );

        // Foundry routes new Contract{salt:}() through the universal CREATE2 factory
        address create2Factory = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
        bytes32 salt = _mineSalt(create2Factory, creationCode, HOOK_FLAGS);
        console.log("Mined salt for hook flags");

        // 3. Deploy RWAGate via CREATE2 — new syntax uses EOA as deployer (matches salt mining)
        RWAGate hook = new RWAGate{salt: salt}(POOL_MANAGER, registry);
        require(uint160(address(hook)) & Hooks.ALL_HOOK_MASK == HOOK_FLAGS, "Hook address flag mismatch");
        console.log("RWAGate deployed at:", address(hook));

        // 4. Initialize USDC/EURC pool
        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(0); // 1:1 price
        (Currency c0_eurc, Currency c1_eurc) = _sortCurrencies(USDC, EURC);
        PoolKey memory keyEurc = PoolKey(c0_eurc, c1_eurc, 3000, 60, IHooks(address(hook)));
        POOL_MANAGER.initialize(keyEurc, sqrtPriceX96);
        console.log("USDC/EURC pool initialized");

        // 5. Initialize USDC/cbBCT pool
        (Currency c0_bct, Currency c1_bct) = _sortCurrencies(USDC, CB_BCT);
        PoolKey memory keyBct = PoolKey(c0_bct, c1_bct, 3000, 60, IHooks(address(hook)));
        POOL_MANAGER.initialize(keyBct, sqrtPriceX96);
        console.log("USDC/cbBCT pool initialized");

        vm.stopBroadcast();

        // Log summary
        console.log("========================================");
        console.log("Deployment Summary (Base Sepolia)");
        console.log("========================================");
        console.log("ComplianceRegistry:", address(registry));
        console.log("RWAGate:           ", address(hook));
        console.log("Operator:          ", deployer);
    }

    /// @dev Mine a CREATE2 salt that produces an address whose lower 14 bits match the desired flags.
    function _mineSalt(address deployer, bytes memory creationCode, uint160 flags)
        internal
        pure
        returns (bytes32)
    {
        bytes32 initCodeHash = keccak256(creationCode);
        for (uint256 i; i < 100_000; ++i) {
            bytes32 salt = bytes32(i);
            address predicted = address(
                uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, initCodeHash))))
            );
            if (uint160(predicted) & Hooks.ALL_HOOK_MASK == flags) {
                return salt;
            }
        }
        revert("Salt not found within 100k iterations");
    }

    function _sortCurrencies(address a, address b) internal pure returns (Currency, Currency) {
        if (a < b) return (Currency.wrap(a), Currency.wrap(b));
        return (Currency.wrap(b), Currency.wrap(a));
    }
}
