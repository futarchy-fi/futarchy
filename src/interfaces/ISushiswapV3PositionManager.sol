// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from "./IERC20Extended.sol";

/**
 * @title ISushiswapV3PositionManager
 * @dev Interface for the SushiSwap V3 NonfungiblePositionManager contract
 */
interface ISushiswapV3PositionManager {
    /**
     * @dev Parameters for mint function
     * @param token0 The address of the first token
     * @param token1 The address of the second token
     * @param fee The fee tier of the pool
     * @param tickLower The lower tick of the position
     * @param tickUpper The upper tick of the position
     * @param amount0Desired The desired amount of token0 to be spent
     * @param amount1Desired The desired amount of token1 to be spent
     * @param amount0Min The minimum amount of token0 to be spent
     * @param amount1Min The minimum amount of token1 to be spent
     * @param recipient The address that will receive the NFT
     * @param deadline The deadline for the transaction
     */
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    /**
     * @dev Creates a new position wrapped in a NFT
     * @param params The parameters for the position
     * @return tokenId The ID of the minted NFT
     * @return liquidity The amount of liquidity for the position
     * @return amount0 The amount of token0 that was deposited
     * @return amount1 The amount of token1 that was deposited
     */
    function mint(MintParams calldata params)
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    /**
     * @dev Creates a pool if it doesn't exist
     * @param tokenA The first token of the pool
     * @param tokenB The second token of the pool
     * @param fee The fee tier of the pool
     * @param sqrtPriceX96 The initial sqrt price of the pool
     * @return pool The address of the pool
     */
    function createAndInitializePoolIfNecessary(
        address tokenA,
        address tokenB,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable returns (address pool);

    /**
     * @dev Returns the address of the SushiSwap V3 factory
     */
    function factory() external view returns (address);

    /**
     * @dev Returns positions information
     * @param tokenId The ID of the NFT
     * @return nonce The nonce for permits
     * @return operator The approved address of the token
     * @return token0 The address of the first token
     * @return token1 The address of the second token
     * @return fee The fee tier of the pool
     * @return tickLower The lower tick of the position
     * @return tickUpper The upper tick of the position
     * @return liquidity The amount of liquidity for the position
     * @return feeGrowthInside0LastX128 The fee growth inside for token0
     * @return feeGrowthInside1LastX128 The fee growth inside for token1
     * @return tokensOwed0 The amount of token0 owed to the position owner
     * @return tokensOwed1 The amount of token1 owed to the position owner
     */
    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
} 