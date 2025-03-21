// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/// @title Uniswap V3 Passthrough Router Interface
/// @notice Router for stateless execution of swaps against Uniswap V3 pools
interface IUniswapV3PassthroughRouter {
    // Structs for swap parameters
    struct TokenInteraction {
        bool zeroForOne;
        int256 amountSpecified;
        uint160 sqrtPriceLimitX96;
        uint256 minAmountReceived;
    }
    
    struct PoolInteraction {
        address pool;
        address recipient;
        bytes callbackData;
    }
    
    /// @notice Returns the current owner of the router
    /// @return The address of the current owner
    function owner() external view returns (address);

    /// @notice Transfers ownership to a new address
    /// @param newOwner The address to transfer ownership to
    function transferOwnership(address newOwner) external;

    /// @notice Authorizes a pool to call the callback function
    /// @param pool The address of the pool to authorize
    function authorizePool(address pool) external;

    /// @notice Deauthorizes a pool from calling the callback function
    /// @param pool The address of the pool to deauthorize
    function deauthorizePool(address pool) external;

    /// @notice Checks if a pool is authorized to call the callback function
    /// @param pool The address of the pool to check
    /// @return True if the pool is authorized, false otherwise
    function authorizedPools(address pool) external view returns (bool);

    /// @notice Executes multiple function calls in a single transaction
    /// @param data Array of encoded function calls to execute
    /// @return results Array of results from each function call
    function multicall(bytes[] calldata data) external returns (bytes[] memory results);

    /// @notice Executes a single call to an external contract
    /// @param target The address of the contract to call
    /// @param value The amount of ETH to send with the call
    /// @param data The calldata to send with the call
    /// @return The return data from the call
    function exec(
        address target,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory);

    /// @notice Swaps tokens through a Uniswap V3 pool
    /// @param poolInfo Information about the pool and recipient
    /// @param tokenInfo Information about the token swap (direction, amounts, price limits)
    /// @return amount0 The delta of the balance of token0 of the pool, exact when negative, minimum when positive
    /// @return amount1 The delta of the balance of token1 of the pool, exact when negative, minimum when positive
    function swap(
        PoolInteraction calldata poolInfo,
        TokenInteraction calldata tokenInfo
    ) external returns (int256 amount0, int256 amount1);
} 