// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

/**
 * @title INonfungiblePositionManager
 * @notice Interface for the Nonfungible Position Manager
 * @dev Manages liquidity positions represented as NFTs
 */
interface INonfungiblePositionManager {
    /**
     * @dev Parameters for mint function
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
     * @dev Parameters for collecting fees
     */
    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    /**
     * @dev Parameters for decreasing liquidity
     */
    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    /**
     * @dev Parameters for increasing liquidity
     */
    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    /**
     * @notice Creates a new pool if it does not exist and initializes it with the given price
     * @param token0 The first token of the pool by address sort order
     * @param token1 The second token of the pool by address sort order
     * @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
     * @param sqrtPriceX96 The initial sqrt price of the pool as a Q64.96 value
     * @return pool The address of the created pool
     */
    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable returns (address pool);

    /**
     * @notice Creates a position and mints an NFT representing it
     * @param params The params necessary to mint a position
     * @return tokenId The ID of the newly minted token
     * @return liquidity The amount of liquidity for this position
     * @return amount0 The amount of token0 that was paid for the position
     * @return amount1 The amount of token1 that was paid for the position
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
     * @notice Returns the address of the position manager factory
     */
    function factory() external view returns (address);

    /**
     * @notice Returns information about a position
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