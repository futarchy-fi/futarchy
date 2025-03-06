// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

/**
 * @title ISushiswapV3PositionManager
 * @notice Interface for the SushiSwap V3 NFT Position Manager
 * @dev Wraps SushiSwap positions in the ERC721 non-fungible token interface
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
     * @notice Creates a new position wrapped in a NFT
     * @param params The parameters necessary for the mint, encoded as MintParams
     * @return tokenId The ID of the token that represents the minted position
     * @return liquidity The amount of liquidity for this position
     * @return amount0 The amount of token0 that was paid to mint the position
     * @return amount1 The amount of token1 that was paid to mint the position
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
     * @notice Creates a new pool if it does not exist and initializes it with a specific sqrt price
     * @param tokenA The first token of the pool by address sort order
     * @param tokenB The second token of the pool by address sort order
     * @param fee The fee that should be collected upon every swap in the pool
     * @param sqrtPriceX96 The initial sqrt price of the pool as a Q64.96
     * @return pool The address of the newly created pool
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
     * @notice Returns the position information associated with a given token ID
     * @param tokenId The ID of the token that represents the position
     * @return nonce The nonce for permits
     * @return operator The address that is approved for spending this token
     * @return token0 The address of the token0 for a specific pool
     * @return token1 The address of the token1 for a specific pool
     * @return fee The fee associated with the pool
     * @return tickLower The lower end of the tick range for the position
     * @return tickUpper The higher end of the tick range for the position
     * @return liquidity The liquidity of the position
     * @return feeGrowthInside0LastX128 The fee growth of token0 as of the last action
     * @return feeGrowthInside1LastX128 The fee growth of token1 as of the last action
     * @return tokensOwed0 The uncollected amount of token0 owed to the position
     * @return tokensOwed1 The uncollected amount of token1 owed to the position
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