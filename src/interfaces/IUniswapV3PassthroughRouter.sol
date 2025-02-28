// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/// @title Uniswap V3 Passthrough Router Interface
/// @notice Router for stateless execution of swaps against Uniswap V3 pools
interface IUniswapV3PassthroughRouter {
    /// @notice Swaps amountSpecified of one token for as much as possible of another token across a single pool
    /// @param pool The Uniswap V3 pool to swap through
    /// @param recipient The address to receive the output of the swap
    /// @param zeroForOne The direction of the swap, true for token0 to token1, false for token1 to token0
    /// @param amountSpecified The amount of the swap, which implicitly configures the swap as exact input (positive), or exact output (negative)
    /// @param sqrtPriceLimitX96 The Q64.96 sqrt price limit. If zero for one, the price cannot be less than this
    /// value after the swap. If one for zero, the price cannot be greater than this value after the swap
    /// @param data Any data to be passed through to the callback
    /// @return amount0 The delta of the balance of token0 of the pool, exact when negative, minimum when positive
    /// @return amount1 The delta of the balance of token1 of the pool, exact when negative, minimum when positive
    function swap(
        address pool,
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
} 