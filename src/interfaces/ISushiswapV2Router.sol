// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from "./IERC20Extended.sol";

/**
 * @title ISushiswapV2Router
 * @dev Interface for the SushiSwap V2 Router contract with functions needed for adding liquidity
 */
interface ISushiswapV2Router {
    /**
     * @dev Adds liquidity to an ERC-20⇄ERC-20 pool
     * @param tokenA The first token of the pair
     * @param tokenB The second token of the pair
     * @param amountADesired The amount of tokenA to add as liquidity
     * @param amountBDesired The amount of tokenB to add as liquidity
     * @param amountAMin The minimum amount of tokenA to add (slippage protection)
     * @param amountBMin The minimum amount of tokenB to add (slippage protection)
     * @param to The address that will receive the LP tokens
     * @param deadline The time by which the transaction must be completed
     * @return amountA The actual amount of tokenA added as liquidity
     * @return amountB The actual amount of tokenB added as liquidity
     * @return liquidity The amount of LP tokens minted
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    
    /**
     * @dev Adds liquidity to an ETH⇄ERC-20 pool
     * @param token The token to be paired with WETH
     * @param amountTokenDesired The amount of token to add as liquidity
     * @param amountTokenMin The minimum amount of token to add as liquidity
     * @param amountETHMin The minimum amount of ETH to add as liquidity
     * @param to The address that will receive the LP tokens
     * @param deadline The time by which the transaction must be completed
     * @return amountToken The actual amount of token added as liquidity
     * @return amountETH The actual amount of ETH added as liquidity
     * @return liquidity The amount of LP tokens minted
     */
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    
    /**
     * @dev Returns the address of the WETH contract
     */
    function WETH() external view returns (address);
    
    /**
     * @dev Returns the address of the factory contract
     */
    function factory() external view returns (address);
} 