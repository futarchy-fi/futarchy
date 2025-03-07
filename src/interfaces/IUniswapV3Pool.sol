// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUniswapV3Pool {
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);
    function liquidity() external view returns (uint128);
    
    /**
     * @notice Swap token0 for token1, or token1 for token0
     * @param recipient The address to receive the output of the swap
     * @param zeroForOne The direction of the swap, true for token0 to token1, false for token1 to token0
     * @param amountSpecified The amount of the swap, which implicitly configures the swap as exact input (positive), or exact output (negative)
     * @param sqrtPriceLimitX96 The Q64.96 sqrt price limit. If zero for one, the price cannot be less than this
     * value after the swap. If one for zero, the price cannot be greater than this value after the swap
     * @param data Any data to be passed through to the callback
     * @return amount0 The delta of the balance of token0 of the pool, exact when negative, minimum when positive
     * @return amount1 The delta of the balance of token1 of the pool, exact when negative, minimum when positive
     */
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
    
    /**
     * @notice Returns the token0 address
     * @return The token0 address
     */
    function token0() external view returns (address);
    
    /**
     * @notice Returns the token1 address
     * @return The token1 address
     */
    function token1() external view returns (address);
}
