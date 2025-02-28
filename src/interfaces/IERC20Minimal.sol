// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/// @title Minimal ERC20 interface for Uniswap
/// @notice Contains only the functions needed to interact with Uniswap
interface IERC20Minimal {
    /// @notice Returns the balance of a token
    /// @param account The account for which to look up the balance
    /// @return The token balance of the account
    function balanceOf(address account) external view returns (uint256);

    /// @notice Transfers the token
    /// @param recipient The account to transfer the token to
    /// @param amount The amount of token to transfer
    /// @return Returns true for a successful transfer
    function transfer(address recipient, uint256 amount) external returns (bool);

    /// @notice Approves spending of the token
    /// @param spender The account allowed to spend the token
    /// @param amount The amount of token allowed to spend
    /// @return Returns true for a successful approval
    function approve(address spender, uint256 amount) external returns (bool);

    /// @notice Transfers the token using the allowance mechanism
    /// @param sender The account to transfer the token from
    /// @param recipient The account to transfer the token to
    /// @param amount The amount of token to transfer
    /// @return Returns true for a successful transferFrom
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
} 