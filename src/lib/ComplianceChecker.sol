// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ComplianceRegistry} from "./ComplianceRegistry.sol";

/// @title ComplianceChecker
/// @notice Stateless validation library. Reverts with typed errors on non-compliance.
library ComplianceChecker {
    // ─── Errors ──────────────────────────────────────────────────────────
    error NotWhitelisted(address account);
    error WhitelistExpired(address account, uint256 expiry);
    error PoolPaused();

    /// @notice Checks compliance for a given sender against a registry.
    ///         Revert priority: PoolPaused > NotWhitelisted > WhitelistExpired
    /// @param registry The compliance registry to query.
    /// @param sender The address to validate.
    function checkCompliance(ComplianceRegistry registry, address sender) internal view {
        // 1. Paused check takes priority
        if (registry.paused()) revert PoolPaused();

        // 2. Whitelist check
        if (!registry.whitelist(sender)) revert NotWhitelisted(sender);

        // 3. Expiry check
        uint256 exp = registry.expiry(sender);
        if (exp != 0 && exp < block.timestamp) revert WhitelistExpired(sender, exp);
    }
}
