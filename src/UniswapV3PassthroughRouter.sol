// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import './interfaces/IUniswapV3Pool.sol';
import './interfaces/callback/IUniswapV3SwapCallback.sol';
import './interfaces/IUniswapV3PassthroughRouter.sol';
import './interfaces/IERC20Minimal.sol';

/// @title Uniswap V3 Passthrough Router
/// @notice Router for stateless execution of swaps against Uniswap V3 pools
contract UniswapV3PassthroughRouter is IUniswapV3PassthroughRouter, IUniswapV3SwapCallback {
    /// @inheritdoc IUniswapV3PassthroughRouter
    function swap(
        address pool,
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external override returns (int256 amount0, int256 amount1) {
        // If amountSpecified is positive, we need to pull tokens from the user ahead of time
        if (amountSpecified > 0) {
            address tokenToPull;
            if (zeroForOne) {
                tokenToPull = IUniswapV3Pool(pool).token0();
            } else {
                tokenToPull = IUniswapV3Pool(pool).token1();
            }
            
            // Pull tokens from the user to this contract
            IERC20Minimal(tokenToPull).transferFrom(
                msg.sender,
                address(this),
                uint256(amountSpecified)
            );
            
            // Approve the pool to spend those tokens
            IERC20Minimal(tokenToPull).approve(pool, uint256(amountSpecified));
        }
        
        // Store just the sender address in callback data (no need to pass tokens now)
        bytes memory callbackData = abi.encode(msg.sender, data);
        
        (amount0, amount1) = IUniswapV3Pool(pool).swap(
            recipient,
            zeroForOne,
            amountSpecified,
            sqrtPriceLimitX96,
            callbackData
        );
    }

    /// @inheritdoc IUniswapV3SwapCallback
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        // Pool address is the caller
        address pool = msg.sender;
        
        // For exact output swaps (amountSpecified < 0), we need to pull tokens at callback time
        if (amount0Delta > 0) {
            // For token0, either:
            // 1. We already have the tokens (exact input for token0->token1)
            // 2. We need to pull tokens now (exact output for token0->token1)
            address token0 = IUniswapV3Pool(pool).token0();
            
            // Check if we already have enough token0 balance
            uint256 routerBalance = IERC20Minimal(token0).balanceOf(address(this));
            if (routerBalance < uint256(amount0Delta)) {
                // Extract original caller from callback data
                (address sender,) = abi.decode(data, (address, bytes));
                
                // Pull additional tokens needed
                uint256 amountNeeded = uint256(amount0Delta) - routerBalance;
                IERC20Minimal(token0).transferFrom(sender, address(this), amountNeeded);
                
                // Approve the pool to spend those tokens
                IERC20Minimal(token0).approve(pool, uint256(amount0Delta));
            }
            
            // Transfer tokens to the pool
            IERC20Minimal(token0).transfer(pool, uint256(amount0Delta));
        }
        
        if (amount1Delta > 0) {
            // For token1, either:
            // 1. We already have the tokens (exact input for token1->token0)
            // 2. We need to pull tokens now (exact output for token1->token0)
            address token1 = IUniswapV3Pool(pool).token1();
            
            // Check if we already have enough token1 balance
            uint256 routerBalance = IERC20Minimal(token1).balanceOf(address(this));
            if (routerBalance < uint256(amount1Delta)) {
                // Extract original caller from callback data
                (address sender,) = abi.decode(data, (address, bytes));
                
                // Pull additional tokens needed
                uint256 amountNeeded = uint256(amount1Delta) - routerBalance;
                IERC20Minimal(token1).transferFrom(sender, address(this), amountNeeded);
                
                // Approve the pool to spend those tokens
                IERC20Minimal(token1).approve(pool, uint256(amount1Delta));
            }
            
            // Transfer tokens to the pool
            IERC20Minimal(token1).transfer(pool, uint256(amount1Delta));
        }
    }
} 