# RWAGate

Uniswap v4 compliance hook that enforces on-chain whitelist-based access control for pools trading regulated Real World Asset tokens. Pure gatekeeper — no pricing or fee modifications.

**Chain:** Base Sepolia (84532)
**Demo Pools:** USDC/EURC (MiCA-regulated FX pair), USDC/cbBCT (tokenized carbon credit)

## Architecture

```
src/
├── RWAGate.sol                 # Hook — gates beforeSwap, beforeAddLiquidity, beforeRemoveLiquidity
└── lib/
    ├── ComplianceRegistry.sol  # Whitelist storage, operator control, pause circuit breaker
    └── ComplianceChecker.sol   # Stateless validation library with typed errors

test/
├── RWAGate.t.sol               # Integration tests (swap, LP, paused, expired)
├── ComplianceRegistry.t.sol    # Unit tests (CRUD, operator transfer, edge cases)
└── ComplianceChecker.t.sol     # Unit tests (revert ordering, typed errors)

script/
├── DeployRWAGate.s.sol         # CREATE2 deployment + pool initialization
└── ConfigureRegistry.s.sol     # Post-deploy whitelist seeding
```

## How It Works

1. **Operator** manages a `ComplianceRegistry` with per-address whitelist status and optional KYC expiry timestamps
2. **RWAGate** hook intercepts `beforeSwap`, `beforeAddLiquidity`, and `beforeRemoveLiquidity` callbacks
3. Each callback calls `ComplianceChecker.checkCompliance(registry, sender)` which enforces:
   - Pool not paused (reverts `PoolPaused()`)
   - Sender is whitelisted (reverts `NotWhitelisted(address)`)
   - Whitelist entry not expired (reverts `WhitelistExpired(address, uint256)`)
4. On success, the hook returns zero delta and zero fee override — no pricing modification

## Base Sepolia Contracts

| Contract | Address | Basescan |
|----------|---------|----------|
| PoolManager | `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408` | [Verified](https://sepolia.basescan.org/address/0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408#code) |
| USDC | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` | [Verified](https://sepolia.basescan.org/address/0x036CbD53842c5426634e7929541eC2318f3dCF7e#code) |
| EURC | `0x808456652fdb597867f38412077A9182bf77359F` | [Verified](https://sepolia.basescan.org/token/0x808456652fdb597867f38412077A9182bf77359F) |
| cbBCT | `0xcbB7C0006F23900c38EB856149F799620fcb8A4a` | [Verified](https://sepolia.basescan.org/address/0xcbB7C0006F23900c38EB856149F799620fcb8A4a#code) |
| PoolSwapTest | `0x8b5bcc363dde2614281ad875bad385e0a785d3b9` | [Verified](https://sepolia.basescan.org/address/0x8b5bcc363dde2614281ad875bad385e0a785d3b9#code) |
| PoolModifyLiquidityTest | `0x37429cd17cb1454c34e7f50b09725202fd533039` | [Verified](https://sepolia.basescan.org/address/0x37429cd17cb1454c34e7f50b09725202fd533039#code) |
| **RWAGate** | _TBD after deployment_ | _TBD_ |
| **ComplianceRegistry** | _TBD after deployment_ | _TBD_ |

## API Reference

### ComplianceRegistry

| Function | Access | Description |
|----------|--------|-------------|
| `addToWhitelist(address, uint256 expiry)` | Operator | Add address with optional expiry (0 = permanent) |
| `batchAddToWhitelist(address[], uint256[])` | Operator | Batch add |
| `removeFromWhitelist(address)` | Operator | Remove (idempotent) |
| `isCompliant(address) → bool` | Public | Check whitelist + expiry + pause |
| `proposeOperator(address)` | Operator | Step 1 of two-step transfer |
| `acceptOperator()` | Pending | Step 2 of two-step transfer |
| `pause()` / `unpause()` | Operator | Circuit breaker |

### Errors

| Error | When |
|-------|------|
| `PoolPaused()` | Registry is paused |
| `NotWhitelisted(address)` | Sender not in whitelist |
| `WhitelistExpired(address, uint256)` | Whitelist entry expired |
| `OnlyOperator()` | Non-operator calls restricted function |
| `OnlyPoolManager()` | Non-PoolManager calls hook callback |

## Integration Guide

### For Router/Protocol Integrators

The `sender` parameter in hook callbacks is the **router contract**, not the end-user EOA. To use RWAGate with your router:

1. Whitelist your router contract address in the ComplianceRegistry
2. Implement your own user-level KYC checks in your router before calling PoolManager

```solidity
// Example: whitelist your router
registry.addToWhitelist(address(myRouter), 0); // permanent
registry.addToWhitelist(address(myRouter), block.timestamp + 365 days); // 1 year
```

### For Pool Creators

```solidity
// Initialize a pool with RWAGate
PoolKey memory key = PoolKey({
    currency0: Currency.wrap(tokenA),
    currency1: Currency.wrap(tokenB),
    fee: 3000,
    tickSpacing: 60,
    hooks: IHooks(rwaGateAddress)
});
poolManager.initialize(key, sqrtPriceX96);
```

## Development

### Build

```shell
forge build
```

### Test

```shell
forge test -vvv
```

### Coverage

```shell
forge coverage
```

### Deploy

```shell
# Set environment variables
export PRIVATE_KEY=<your_private_key>
export RPC_URL=https://sepolia.base.org

# Deploy
forge script script/DeployRWAGate.s.sol --rpc-url $RPC_URL --broadcast

# Verify on Basescan
forge verify-contract <REGISTRY_ADDR> src/lib/ComplianceRegistry.sol:ComplianceRegistry \
  --chain base-sepolia --constructor-args $(cast abi-encode "constructor(address)" <DEPLOYER>)

forge verify-contract <HOOK_ADDR> src/RWAGate.sol:RWAGate \
  --chain base-sepolia --constructor-args $(cast abi-encode "constructor(address,address)" <POOL_MANAGER> <REGISTRY>)
```

### Configure Whitelist

```shell
export REGISTRY_ADDRESS=<deployed_registry>
export TEST_ADDR_1=<addr1>
export TEST_ADDR_2=<addr2>
export TEST_ADDR_3=<addr3>

forge script script/ConfigureRegistry.s.sol --rpc-url $RPC_URL --broadcast
```

## Security

- `onlyPoolManager` on all hook callbacks
- CEI enforced — no external calls inside hook callbacks beyond registry reads
- Two-step operator transfer (propose/accept)
- No `tx.origin` usage
- No user-supplied external addresses accepted
- Hook holds zero token balances

## Known Limitations

- `sender` in `beforeSwap` is the router contract, not the end-user EOA. User-level KYC must be enforced at the router layer.
- Single `ComplianceRegistry` serves all pools registered to the same hook deployment.

## Test Coverage

```
| File                           | Lines   | Statements | Branches | Functions |
|--------------------------------|---------|------------|----------|-----------|
| src/RWAGate.sol                | 100.00% | 100.00%    | 100.00%  | 100.00%   |
| src/lib/ComplianceChecker.sol  | 100.00% | 100.00%    | 100.00%  | 100.00%   |
| src/lib/ComplianceRegistry.sol | 100.00% | 100.00%    | 100.00%  | 100.00%   |
```

## License

MIT
