# RWAGate

Uniswap v4 compliance hook that enforces on-chain whitelist-based access control for pools trading regulated Real World Asset tokens. Pure gatekeeper — no pricing or fee modifications.

**Chain:** Arc Testnet (5042002) · also deployed on Base Sepolia (84532)
**Demo Pool:** USDC/EURC (MiCA-regulated FX pair)

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

## Arc Testnet Contracts

Chain ID `5042002` · RPC `https://rpc.testnet.arc.network` · Explorer https://testnet.arcscan.app

Arc has no canonical Uniswap v4 deployment, so this deployment ships its own `PoolManager` and
test routers alongside the hook. On Arc, USDC is the native gas token; `0x3600…0000` is its ERC-20
interface. Verified end-to-end: a 0.1 USDC → ~0.0997 EURC swap (0.30% fee) executes through the
RWAGate-gated pool.

| Contract | Address | Arcscan |
|----------|---------|---------|
| **RWAGate (HOOK)** | `0xda483a6374AEeB3ffA6D8a2772D6c2e64d314a80` | [View](https://testnet.arcscan.app/address/0xda483a6374AEeB3ffA6D8a2772D6c2e64d314a80) |
| **ComplianceRegistry** | `0x2978eA98Cc3c5c480d4C9D073DF8599BA761556D` | [View](https://testnet.arcscan.app/address/0x2978eA98Cc3c5c480d4C9D073DF8599BA761556D) |
| PoolManager (v4) | `0xA29B7D158f2b2113Bd60eeD765866f794096D4Dc` | [View](https://testnet.arcscan.app/address/0xA29B7D158f2b2113Bd60eeD765866f794096D4Dc) |
| PoolSwapTest | `0x97dA0bEf8FCa63D9B597AF54b76B25d4f89FbD14` | [View](https://testnet.arcscan.app/address/0x97dA0bEf8FCa63D9B597AF54b76B25d4f89FbD14) |
| PoolModifyLiquidityTest | `0xa9A1c3BC2acB424b0e688B8a19E0a4Af76bA43e5` | [View](https://testnet.arcscan.app/address/0xa9A1c3BC2acB424b0e688B8a19E0a4Af76bA43e5) |
| USDC | `0x3600000000000000000000000000000000000000` | [View](https://testnet.arcscan.app/address/0x3600000000000000000000000000000000000000) |
| EURC | `0x89B50855Aa3bE2F677cD6303Cec089B5F319D72a` | [View](https://testnet.arcscan.app/address/0x89B50855Aa3bE2F677cD6303Cec089B5F319D72a) |

Pool: `currency0 = USDC`, `currency1 = EURC`, `fee = 3000`, `tickSpacing = 60`, `hooks = RWAGate`.

## Base Sepolia Contracts

| Contract | Address | Basescan |
|----------|---------|----------|
| PoolManager | `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408` | [Verified](https://sepolia.basescan.org/address/0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408#code) |
| USDC | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` | [Verified](https://sepolia.basescan.org/address/0x036CbD53842c5426634e7929541eC2318f3dCF7e#code) |
| EURC | `0x808456652fdb597867f38412077A9182bf77359F` | [Verified](https://sepolia.basescan.org/token/0x808456652fdb597867f38412077A9182bf77359F) |
| cbBCT | `0xcbB7C0006F23900c38EB856149F799620fcb8A4a` | [Verified](https://sepolia.basescan.org/address/0xcbB7C0006F23900c38EB856149F799620fcb8A4a#code) |
| PoolSwapTest | `0x8b5bcc363dde2614281ad875bad385e0a785d3b9` | [Verified](https://sepolia.basescan.org/address/0x8b5bcc363dde2614281ad875bad385e0a785d3b9#code) |
| PoolModifyLiquidityTest | `0x37429cd17cb1454c34e7f50b09725202fd533039` | [Verified](https://sepolia.basescan.org/address/0x37429cd17cb1454c34e7f50b09725202fd533039#code) |
| **RWAGate** | `0xbba7Cf860B47E16b9b83d8185878Ec0FAD0d4a80` | [Verified](https://sepolia.basescan.org/address/0xbba7Cf860B47E16b9b83d8185878Ec0FAD0d4a80#code) |
| **ComplianceRegistry** | `0x11B261AE5AF867baA69506dfE6d62eeE9DB5D796` | [Verified](https://sepolia.basescan.org/address/0x11B261AE5AF867baA69506dfE6d62eeE9DB5D796#code) |

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

### Deploy to Arc Testnet

Arc uses USDC as its native gas token — fund the deployer with testnet USDC from
https://faucet.circle.com first. Use an encrypted keystore rather than a plaintext key:

```shell
# One-time: import the deployer key into an encrypted keystore
cast wallet import rwagate-deployer --interactive

export DEPLOYER=<deployer_address>

# Deploys PoolManager + ComplianceRegistry + RWAGate (CREATE2) + test routers,
# whitelists the routers, and initializes the USDC/EURC pool.
forge script script/DeployRWAGateArc.s.sol:DeployRWAGateArc \
  --rpc-url https://rpc.testnet.arc.network \
  --account rwagate-deployer --sender $DEPLOYER --broadcast --slow
```

Seed liquidity and run a proof swap (driven with `cast send` because Foundry's local
fork cannot execute Arc's native-USDC blocklist precompile — see the script header):

```shell
export POOL_MANAGER=<pool_manager>  HOOK=<hook>
export SWAP_ROUTER=<swap_router>    LP_ROUTER=<lp_router>
# Approve USDC/EURC to the routers, then call modifyLiquidity / swap via cast send.
```

### Deploy to Base Sepolia

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
