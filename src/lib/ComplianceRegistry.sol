// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title ComplianceRegistry
/// @notice Manages a whitelist of addresses with optional KYC expiry timestamps.
///         Supports pause/unpause and two-step operator transfer.
contract ComplianceRegistry {
    // ─── State ───────────────────────────────────────────────────────────
    mapping(address => bool) public whitelist;
    mapping(address => uint256) public expiry;

    address public operator;
    address public pendingOperator;
    bool public paused;

    // ─── Events ──────────────────────────────────────────────────────────
    event Whitelisted(address indexed account, uint256 expiry);
    event Removed(address indexed account);
    event OperatorProposed(address indexed current, address indexed proposed);
    event OperatorAccepted(address indexed previous, address indexed current);
    event Paused();
    event Unpaused();

    // ─── Errors ──────────────────────────────────────────────────────────
    error OnlyOperator();
    error ZeroAddress();
    error ExpiryInPast(uint256 expiry);
    error OnlyPendingOperator();

    // ─── Modifiers ───────────────────────────────────────────────────────
    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    // ─── Constructor ─────────────────────────────────────────────────────
    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
    }

    // ─── Whitelist Management ────────────────────────────────────────────

    /// @notice Add an address to the whitelist with an optional expiry.
    /// @param account The address to whitelist.
    /// @param _expiry Unix timestamp when the whitelist entry expires. 0 = no expiry.
    function addToWhitelist(address account, uint256 _expiry) external onlyOperator {
        if (account == address(0)) revert ZeroAddress();
        if (_expiry != 0 && _expiry < block.timestamp) revert ExpiryInPast(_expiry);

        whitelist[account] = true;
        expiry[account] = _expiry;

        emit Whitelisted(account, _expiry);
    }

    /// @notice Batch-add addresses to the whitelist.
    /// @param accounts The addresses to whitelist.
    /// @param expiries Corresponding expiry timestamps.
    function batchAddToWhitelist(address[] calldata accounts, uint256[] calldata expiries) external onlyOperator {
        require(accounts.length == expiries.length, "length mismatch");
        for (uint256 i; i < accounts.length; ++i) {
            if (accounts[i] == address(0)) revert ZeroAddress();
            if (expiries[i] != 0 && expiries[i] < block.timestamp) revert ExpiryInPast(expiries[i]);

            whitelist[accounts[i]] = true;
            expiry[accounts[i]] = expiries[i];

            emit Whitelisted(accounts[i], expiries[i]);
        }
    }

    /// @notice Remove an address from the whitelist. Idempotent.
    function removeFromWhitelist(address account) external onlyOperator {
        whitelist[account] = false;
        expiry[account] = 0;
        emit Removed(account);
    }

    // ─── Compliance Query ────────────────────────────────────────────────

    /// @notice Check if an address is compliant (whitelisted, not expired, pool not paused).
    function isCompliant(address account) external view returns (bool) {
        if (paused) return false;
        if (!whitelist[account]) return false;
        uint256 exp = expiry[account];
        if (exp != 0 && exp < block.timestamp) return false;
        return true;
    }

    // ─── Operator Transfer ───────────────────────────────────────────────

    /// @notice Propose a new operator. Must be accepted by the proposed address.
    function proposeOperator(address _pendingOperator) external onlyOperator {
        if (_pendingOperator == address(0)) revert ZeroAddress();
        pendingOperator = _pendingOperator;
        emit OperatorProposed(operator, _pendingOperator);
    }

    /// @notice Accept the operator role. Caller must be the pending operator.
    function acceptOperator() external {
        if (msg.sender != pendingOperator) revert OnlyPendingOperator();
        address previous = operator;
        operator = msg.sender;
        pendingOperator = address(0);
        emit OperatorAccepted(previous, msg.sender);
    }

    // ─── Pause ───────────────────────────────────────────────────────────

    function pause() external onlyOperator {
        paused = true;
        emit Paused();
    }

    function unpause() external onlyOperator {
        paused = false;
        emit Unpaused();
    }
}
