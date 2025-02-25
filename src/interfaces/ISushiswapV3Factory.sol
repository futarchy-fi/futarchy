// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/**
 * @title ISushiswapV3Factory
 * @dev Interface for the SushiSwap V3 Factory contract
 */
interface ISushiswapV3Factory {
    /**
     * @dev Creates a new pool for the given tokens and fee
     * @param tokenA The first token of the pool
     * @param tokenB The second token of the pool
     * @param fee The fee tier of the pool
     * @return pool The address of the created pool
     */
    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pool);

    /**
     * @dev Returns the pool address for the given tokens and fee
     * @param tokenA The first token of the pool
     * @param tokenB The second token of the pool
     * @param fee The fee tier of the pool
     * @return pool The address of the pool
     */
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool);

    /**
     * @dev Returns the fee amount tick spacing mapping
     * @param fee The fee tier
     * @return tickSpacing The tick spacing for the fee tier
     */
    function feeAmountTickSpacing(uint24 fee) external view returns (int24 tickSpacing);

    /**
     * @dev Returns the owner of the factory
     */
    function owner() external view returns (address);

    /**
     * @dev Sets the owner of the factory
     * @param _owner The new owner
     */
    function setOwner(address _owner) external;

    /**
     * @dev Enables a new fee tier with the given tick spacing
     * @param fee The fee tier to enable
     * @param tickSpacing The tick spacing for the fee tier
     */
    function enableFeeAmount(uint24 fee, int24 tickSpacing) external;
} 