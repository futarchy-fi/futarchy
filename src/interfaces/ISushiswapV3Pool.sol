// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/**
 * @title ISushiswapV3Pool
 * @dev Interface for the SushiSwap V3 Pool contract
 */
interface ISushiswapV3Pool {
    /**
     * @dev Returns the first token of the pool
     */
    function token0() external view returns (address);

    /**
     * @dev Returns the second token of the pool
     */
    function token1() external view returns (address);

    /**
     * @dev Returns the fee tier of the pool
     */
    function fee() external view returns (uint24);

    /**
     * @dev Returns the tick spacing of the pool
     */
    function tickSpacing() external view returns (int24);

    /**
     * @dev Returns the factory address
     */
    function factory() external view returns (address);

    /**
     * @dev Returns the maximum amount of liquidity per tick
     */
    function maxLiquidityPerTick() external view returns (uint128);

    /**
     * @dev Returns the current price of the pool as a sqrt(token1/token0) Q64.96 value
     */
    function slot0() external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    );

    /**
     * @dev Returns ticks bitmap
     * @param wordPosition The position of the word
     */
    function tickBitmap(int16 wordPosition) external view returns (uint256);

    /**
     * @dev Initializes the pool with the given sqrt price
     * @param sqrtPriceX96 The initial sqrt price of the pool as a Q64.96
     */
    function initialize(uint160 sqrtPriceX96) external;

    /**
     * @dev Returns information about a position
     * @param key The position key (keccak256(address owner, int24 tickLower, int24 tickUpper))
     * @return liquidity The amount of liquidity in the position
     * @return feeGrowthInside0LastX128 The fee growth inside the position for token0
     * @return feeGrowthInside1LastX128 The fee growth inside the position for token1
     * @return tokensOwed0 The amount of token0 owed to the position owner
     * @return tokensOwed1 The amount of token1 owed to the position owner
     */
    function positions(
        bytes32 key
    ) external view returns (
        uint128 liquidity,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    );

    /**
     * @dev Returns the current liquidity of the pool
     */
    function liquidity() external view returns (uint128);
} 