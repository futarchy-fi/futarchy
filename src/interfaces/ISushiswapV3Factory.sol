// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

/**
 * @title ISushiswapV3Factory
 * @notice Interface for the SushiSwap V3 Factory contract which deploys pools
 */
interface ISushiswapV3Factory {
    /**
     * @notice Creates a pool for the given two tokens and fee
     * @param tokenA The first token of the pool by address sort order
     * @param tokenB The second token of the pool by address sort order
     * @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
     * @return pool The address of the newly created pool
     */
    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pool);

    /**
     * @notice Returns the pool address for a given pair of tokens and a fee, or address 0 if it does not exist
     * @param tokenA The first token of the pool by address sort order
     * @param tokenB The second token of the pool by address sort order
     * @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
     * @return pool The pool address
     */
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool);

    /**
     * @notice Returns the current owner of the factory
     * @return The address of the factory owner
     */
    function owner() external view returns (address);

    /**
     * @notice Returns the tick spacing for a given fee tier
     * @param fee The fee tier to get the tick spacing for
     * @return The tick spacing
     */
    function feeAmountTickSpacing(uint24 fee) external view returns (int24);
} 