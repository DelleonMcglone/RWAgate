# Contributing to RWAGate

Thank you for your interest in contributing to RWAGate! This document provides guidelines and instructions for contributing to this Uniswap V4 compliance hook project.

## Project Overview

RWAGate is a Uniswap V4 hook that enforces on-chain whitelist-based access control for pools trading regulated Real World Asset (RWA) tokens. It's designed for compliance with regulations like MiCA and operates on Base Sepolia (chain ID: 84532).

### Key Components

- **RWAGate.sol**: The main hook contract implementing `beforeSwap`, `beforeAddLiquidity`, and `beforeRemoveLiquidity` callbacks
- **ComplianceRegistry.sol**: Whitelist storage with operator control and circuit breaker functionality
- **ComplianceChecker.sol**: Stateless validation library with typed errors

## Development Setup

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (latest version)
- Git
- An Ethereum wallet with Base Sepolia ETH (for testing deployments)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/DelleonMcglone/RWAgate.git
cd RWAgate
```

2. Install dependencies:
```bash
forge install
```

3. Build the project:
```bash
forge build
```

4. Run tests:
```bash
forge test
```

## Project Structure

```
RWAGate/
├── src/
│   ├── RWAGate.sol              # Main hook contract
│   └── lib/
│       ├── ComplianceRegistry.sol
│       └── ComplianceChecker.sol
├── test/
│   ├── RWAGate.t.sol            # Integration tests
│   ├── ComplianceRegistry.t.sol # Unit tests
│   └── ComplianceChecker.t.sol  # Unit tests
├── script/
│   ├── DeployRWAGate.s.sol      # Deployment script
│   └── ConfigureRegistry.s.sol  # Registry configuration
├── foundry.toml                 # Foundry configuration
└── README.md
```

## Coding Standards

### Solidity Style Guide

- **Solidity Version**: Use `0.8.26` as specified in `foundry.toml`
- **EVM Version**: Target `cancun` for Uniswap V4 compatibility
- **Line Length**: Maximum 120 characters (enforced by `forge fmt`)
- **Indentation**: 4 spaces

### Code Formatting

Always run the formatter before committing:

```bash
forge fmt
```

### Naming Conventions

- **Contracts**: PascalCase (e.g., `ComplianceRegistry`)
- **Functions**: camelCase (e.g., `checkCompliance`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_KYC_EXPIRY`)
- **Events**: PascalCase with verb prefix (e.g., `AddressWhitelisted`)
- **Errors**: PascalCase with descriptive names (e.g., `ComplianceExpired`)

### Documentation

- Use NatSpec comments for all public/external functions
- Include `@notice`, `@param`, and `@return` tags
- Document complex logic with inline comments

Example:
```solidity
/// @notice Checks if an address is compliant for pool interactions
/// @param registry The compliance registry to check against
/// @param sender The address to validate
/// @return True if compliant, reverts otherwise
function checkCompliance(address registry, address sender) internal view returns (bool) {
    // Implementation
}
```

## Testing Guidelines

### Running Tests

```bash
# Run all tests
forge test

# Run with verbosity
forge test -v

# Run specific test file
forge test --match-path test/RWAGate.t.sol

# Run with gas reporting
forge test --gas-report
```

### Test Structure

- **Unit Tests**: Test individual functions in isolation
- **Integration Tests**: Test hook interactions with Uniswap V4 pools
- **Fuzz Tests**: Use Foundry's fuzzing capabilities for edge cases

### Writing Tests

1. **Fork Testing**: Use Base Sepolia fork for integration tests:
```solidity
// In your test file
string memory rpcUrl = vm.envString("BASE_SEPOLIA_RPC");
vm.createSelectFork(rpcUrl);
```

2. **Test Coverage**: Aim for >90% code coverage
3. **Edge Cases**: Test boundary conditions (expired KYC, paused state, etc.)

### Environment Variables

Create a `.env` file for sensitive data (never commit this):

```bash
BASE_SEPOLIA_RPC=https://sepolia.base.org
PRIVATE_KEY=your_private_key_here
```

Load it in tests:
```bash
source .env && forge test
```

## Contribution Areas

### High Priority

1. **Additional Hook Callbacks**: Implement `afterSwap`, `afterAddLiquidity` for enhanced monitoring
2. **Multi-Registry Support**: Allow hooks to query multiple compliance registries
3. **Time-Weighted Compliance**: Add reputation scoring based on historical compliance

### Medium Priority

1. **Gas Optimization**: Reduce gas costs for compliance checks
2. **Additional Test Coverage**: Fuzzing and invariant tests
3. **Documentation**: Expand inline documentation and examples
4. **Mainnet Deployment**: Prepare for Base mainnet deployment

### Low Priority

1. **Frontend Integration**: Example dApp for registry management
2. **Analytics**: On-chain compliance event indexing
3. **Multi-Chain Support**: Adapt for other EVM chains

## Security Considerations

⚠️ **Critical**: This hook controls access to financial pools. Always:

- Test thoroughly on Base Sepolia before any mainnet consideration
- Have changes reviewed by multiple contributors
- Consider formal verification for critical paths
- Never commit private keys or sensitive data

### Security Checklist

- [ ] All state changes are validated
- [ ] Access controls are properly implemented
- [ ] Reentrancy guards are in place where needed
- [ ] Integer overflow/underflow is prevented (Solidity 0.8.x helps)
- [ ] Events are emitted for all state changes

## Submitting Changes

### Pull Request Process

1. **Fork** the repository
2. **Create a branch**: `git checkout -b feature/your-feature-name`
3. **Make changes** following the coding standards
4. **Run tests**: Ensure all tests pass
5. **Format code**: Run `forge fmt`
6. **Commit** with clear messages
7. **Push** to your fork
8. **Open a Pull Request** with:
   - Clear description of changes
   - Link to any related issues
   - Test results
   - Security considerations if applicable

### Commit Message Format

```
type(scope): description

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `docs`, `test`, `refactor`, `perf`, `chore`

Example:
```
feat(registry): add batch whitelist functionality

- Add batchAddToWhitelist function for gas efficiency
- Add corresponding events and tests
- Update documentation

Closes #123
```

## Getting Help

- **Discord**: [Base Discord](https://discord.gg/buildonbase)
- **Uniswap V4 Docs**: [docs.uniswap.org](https://docs.uniswap.org/contracts/v4/overview)
- **Foundry Book**: [book.getfoundry.sh](https://book.getfoundry.sh)

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

---

**Thank you for helping build compliant DeFi infrastructure on Base!** 🏗️
