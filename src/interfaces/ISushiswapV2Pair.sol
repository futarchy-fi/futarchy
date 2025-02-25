// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/**
 * @title ISushiswapV2Pair
 * @dev Interface for the SushiSwap V2 Pair contract
 */
interface ISushiswapV2Pair {
    /**
     * @dev Returns the factory that created this pair
     */
    function factory() external view returns (address);
    
    /**
     * @dev Returns the address of token0
     */
    function token0() external view returns (address);
    
    /**
     * @dev Returns the address of token1
     */
    function token1() external view returns (address);
    
    /**
     * @dev Returns the current reserves and timestamp of the pair
     * @return reserve0 The reserve of token0
     * @return reserve1 The reserve of token1
     * @return blockTimestampLast The timestamp of the last update
     */
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    
    /**
     * @dev Initializes the pair with token0 and token1
     * @param token0 The first token of the pair
     * @param token1 The second token of the pair
     */
    function initialize(address token0, address token1) external;
    
    /**
     * @dev Adds liquidity to the pair
     * @param to The address to receive LP tokens
     * @return liquidity The amount of LP tokens minted
     */
    function mint(address to) external returns (uint liquidity);
    
    /**
     * @dev Removes liquidity from the pair
     * @param to The address to receive the underlying tokens
     * @return amount0 The amount of token0 withdrawn
     * @return amount1 The amount of token1 withdrawn
     */
    function burn(address to) external returns (uint amount0, uint amount1);
    
    /**
     * @dev Swaps tokens
     * @param amount0Out The amount of token0 to receive
     * @param amount1Out The amount of token1 to receive
     * @param to The address to receive the tokens
     * @param data Additional data to pass to the callback
     */
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
} 