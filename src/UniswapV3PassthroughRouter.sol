// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import './interfaces/IUniswapV3Pool.sol';
import './interfaces/callback/IUniswapV3SwapCallback.sol';
import './interfaces/IUniswapV3PassthroughRouter.sol';
import './interfaces/IERC20Minimal.sol';

/// @title Uniswap V3 Passthrough Router
/// @notice Router for stateless execution of swaps against Uniswap V3 pools
contract UniswapV3PassthroughRouter is IUniswapV3PassthroughRouter, IUniswapV3SwapCallback {
    // Owner of the contract
    address public owner;
    
    // Mapping to track authorized pool addresses
    mapping(address => bool) public authorizedPools;

    // Events
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PoolAuthorized(address indexed pool);
    event PoolDeauthorized(address indexed pool);
    
    // Modifier to restrict function access to the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "UniswapV3Router: caller is not the owner");
        _;
    }
    
    // Constructor sets the deployer as the initial owner
    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }
    
    // Transfer ownership to a new address
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "UniswapV3Router: new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    // Authorize a pool to call the callback function
    function authorizePool(address pool) external onlyOwner {
        authorizedPools[pool] = true;
        emit PoolAuthorized(pool);
    }
    
    // Deauthorize a pool
    function deauthorizePool(address pool) external onlyOwner {
        authorizedPools[pool] = false;
        emit PoolDeauthorized(pool);
    }
    
    // Multicall function to batch multiple calls in a single transaction
    function multicall(bytes[] calldata data) external onlyOwner returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);
            require(success, "UniswapV3Router: delegatecall failed");
            results[i] = result;
        }
        return results;
    }

    // Single call
    function exec(
        address target,
        uint256 value,
        bytes calldata data
    ) external payable onlyOwner returns (bytes memory) {
        (bool success, bytes memory result) = target.call{value: value}(data);
        require(success, "Call failed");
        return result;
    }

    /// @inheritdoc IUniswapV3PassthroughRouter
    function swap(
        PoolInteraction calldata poolInfo,
        TokenInteraction calldata tokenInfo
    ) external onlyOwner returns (int256 amount0, int256 amount1) {
        // If amountSpecified is positive, we need to pull tokens from the user ahead of time
        if (tokenInfo.amountSpecified > 0) {
            address tokenToPull;
            if (tokenInfo.zeroForOne) {
                tokenToPull = IUniswapV3Pool(poolInfo.pool).token0();
            } else {
                tokenToPull = IUniswapV3Pool(poolInfo.pool).token1();
            }
            
            // Pull tokens from the owner to this contract
            IERC20Minimal(tokenToPull).transferFrom(
                msg.sender,
                address(this),
                uint256(tokenInfo.amountSpecified)
            );
            
            // Approve the pool to spend those tokens
            IERC20Minimal(tokenToPull).approve(poolInfo.pool, uint256(tokenInfo.amountSpecified));
        }
        
        // Authorize pool if not already authorized
        if (!authorizedPools[poolInfo.pool]) {
            authorizedPools[poolInfo.pool] = true;
            emit PoolAuthorized(poolInfo.pool);
        }
        
        // Store just the sender address in callback data (no need to pass tokens now)
        bytes memory callbackData = abi.encode(msg.sender, poolInfo.callbackData);
        
        (amount0, amount1) = IUniswapV3Pool(poolInfo.pool).swap(
            poolInfo.recipient,
            tokenInfo.zeroForOne,
            tokenInfo.amountSpecified,
            tokenInfo.sqrtPriceLimitX96,
            callbackData
        );

        // Check that the minimum amount received is satisfied
        if (tokenInfo.zeroForOne) {
            // When swapping token0 for token1, amount1 should be negative (tokens received)
            require(-amount1 >= int256(tokenInfo.minAmountReceived), "UniswapV3Router: insufficient output amount");
        } else {
            // When swapping token1 for token0, amount0 should be negative (tokens received)
            require(-amount0 >= int256(tokenInfo.minAmountReceived), "UniswapV3Router: insufficient output amount");
        }
    }

    /// @inheritdoc IUniswapV3SwapCallback
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        // Pool address is the caller
        address pool = msg.sender;
        
        // Verify the pool is authorized
        require(authorizedPools[pool], "UniswapV3Router: pool not authorized");
        
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
                
                // Ensure sender is owner
                require(sender == owner, "UniswapV3Router: sender is not owner");
                
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
                
                // Ensure sender is owner
                require(sender == owner, "UniswapV3Router: sender is not owner");
                
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