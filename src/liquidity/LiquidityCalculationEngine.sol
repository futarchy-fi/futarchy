// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../price-oracle/PriceOracleService.sol";
import "../price-oracle/SushiswapPriceOracle.sol";

/**
 * @title LiquidityCalculationEngine
 * @notice Calculates optimal liquidity amounts and ratios for v2 and v3 pools
 * @dev Uses Balancer prices to determine proper liquidity distribution
 */
contract LiquidityCalculationEngine is Script {
    // Structs for token and pool data
    struct TokenData {
        address tokenAddress;
        string tokenType;
        string symbol;
        uint8 decimals;
        address collateralToken;
    }

    struct PoolLiquidity {
        address token0;
        address token1;
        uint256 amount0;
        uint256 amount1;
        uint256 initialPrice;
        bool isV3;
        int24 tickLower;   // Only for v3 pools
        int24 tickUpper;   // Only for v3 pools
        uint24 fee;        // Only for v3 pools
    }

    struct LiquidityConfig {
        uint256 wxdaiAmount;        // WXDAI amount per v2 pool
        uint256 token1Amount;       // Token1 amount for v3 liquidity
        uint256 token2Amount;       // Token2 amount for v3 liquidity
    }

    struct TokenPrices {
        uint256 token1YesPrice;     // Token1 YES price in WXDAI
        uint256 token1NoPrice;      // Token1 NO price in WXDAI
        uint256 token2YesPrice;     // Token2 YES price in WXDAI
        uint256 token2NoPrice;      // Token2 NO price in WXDAI
    }

    // Constants
    uint24 constant V3_FEE_TIER = 1000;      // 0.1% fee tier for v3 pools
    uint256 constant PRICE_RANGE_MULTIPLIER = 12e17; // 1.2x for ±20% price range
    
    /**
     * @notice Calculates liquidity parameters for all pools
     * @param tokens Array of token data from extraction
     * @param priceData Price data for tokens
     * @param config Liquidity configuration from JSON
     * @return pools Array of pool liquidity data
     */
    function calculateAllPoolLiquidity(
        TokenData[] memory tokens,
        PriceOracleService.ProposalPriceData memory priceData,
        LiquidityConfig memory config
    ) public returns (PoolLiquidity[] memory) {
        console.log("Calculating liquidity for all pools...");
        
        // Convert price data to our internal format
        TokenPrices memory prices = TokenPrices({
            token1YesPrice: priceData.token1YesPrice,
            token1NoPrice: priceData.token1NoPrice,
            token2YesPrice: priceData.token2YesPrice,
            token2NoPrice: priceData.token2NoPrice
        });
        
        // Calculate v2 token-WXDAI pools (YES/WXDAI and NO/WXDAI)
        PoolLiquidity[] memory v2TokenWxdaiPools = calculateV2TokenWXDAIPools(
            tokens,
            prices,
            config.wxdaiAmount
        );
        
        // Calculate v2 YES/YES and NO/NO pools
        PoolLiquidity[] memory v2YesNoPools = calculateV2YesNoPools(
            tokens,
            prices
        );
        
        // Calculate v3 pools with concentrated liquidity
        PoolLiquidity[] memory v3Pools = calculateV3Pools(
            tokens,
            prices,
            config.token1Amount,
            config.token2Amount,
            PRICE_RANGE_MULTIPLIER
        );
        
        // Combine all pool configurations
        PoolLiquidity[] memory allPools = new PoolLiquidity[](
            v2TokenWxdaiPools.length + v2YesNoPools.length + v3Pools.length
        );
        
        uint256 poolIndex = 0;
        
        // Add v2 token-WXDAI pools
        for (uint256 i = 0; i < v2TokenWxdaiPools.length; i++) {
            allPools[poolIndex] = v2TokenWxdaiPools[i];
            poolIndex++;
        }
        
        // Add v2 YES/YES and NO/NO pools
        for (uint256 i = 0; i < v2YesNoPools.length; i++) {
            allPools[poolIndex] = v2YesNoPools[i];
            poolIndex++;
        }
        
        // Add v3 pools
        for (uint256 i = 0; i < v3Pools.length; i++) {
            allPools[poolIndex] = v3Pools[i];
            poolIndex++;
        }
        
        // Log the results
        logPoolLiquidity(allPools);
        
        return allPools;
    }
    
    /**
     * @notice Calculates liquidity for v2 token-WXDAI pools
     * @param tokens Array of token data
     * @param prices Token prices
     * @param wxdaiAmount WXDAI amount from config
     * @return pools Array of v2 token-WXDAI pool liquidity data
     */
    function calculateV2TokenWXDAIPools(
        TokenData[] memory tokens,
        TokenPrices memory prices,
        uint256 wxdaiAmount
    ) internal returns (PoolLiquidity[] memory) {
        console.log("Calculating v2 token-WXDAI pools...");
        
        // We need 4 pools: YES_token1/WXDAI, NO_token1/WXDAI, YES_token2/WXDAI, NO_token2/WXDAI
        PoolLiquidity[] memory pools = new PoolLiquidity[](4);
        
        // Find relevant tokens and WXDAI address
        address wxdaiAddress;
        address token1YesAddress;
        address token1NoAddress;
        address token2YesAddress;
        address token2NoAddress;
        
        for (uint256 i = 0; i < tokens.length; i++) {
            if (keccak256(bytes(tokens[i].tokenType)) == keccak256(bytes("token1Yes"))) {
                token1YesAddress = tokens[i].tokenAddress;
            } else if (keccak256(bytes(tokens[i].tokenType)) == keccak256(bytes("token1No"))) {
                token1NoAddress = tokens[i].tokenAddress;
            } else if (keccak256(bytes(tokens[i].tokenType)) == keccak256(bytes("token2Yes"))) {
                token2YesAddress = tokens[i].tokenAddress;
            } else if (keccak256(bytes(tokens[i].tokenType)) == keccak256(bytes("token2No"))) {
                token2NoAddress = tokens[i].tokenAddress;
            }
            
            // Get WXDAI address from environment
            wxdaiAddress = vm.envAddress("WXDAI_ADDRESS");
        }
        
        // Calculate token amounts based on prices
        // For v2 pools, the product of token amounts should equal their ratio to maintain price
        
        // Pool 1: YES_token1/WXDAI
        uint256 token1YesAmount = (wxdaiAmount * 1e18) / prices.token1YesPrice;
        pools[0] = PoolLiquidity({
            token0: wxdaiAddress,
            token1: token1YesAddress,
            amount0: wxdaiAmount,
            amount1: token1YesAmount,
            initialPrice: prices.token1YesPrice,
            isV3: false,
            tickLower: 0,
            tickUpper: 0,
            fee: 0
        });
        
        // Pool 2: NO_token1/WXDAI
        uint256 token1NoAmount = (wxdaiAmount * 1e18) / prices.token1NoPrice;
        pools[1] = PoolLiquidity({
            token0: wxdaiAddress,
            token1: token1NoAddress,
            amount0: wxdaiAmount,
            amount1: token1NoAmount,
            initialPrice: prices.token1NoPrice,
            isV3: false,
            tickLower: 0,
            tickUpper: 0,
            fee: 0
        });
        
        // Pool 3: YES_token2/WXDAI
        uint256 token2YesAmount = (wxdaiAmount * 1e18) / prices.token2YesPrice;
        pools[2] = PoolLiquidity({
            token0: wxdaiAddress,
            token1: token2YesAddress,
            amount0: wxdaiAmount,
            amount1: token2YesAmount,
            initialPrice: prices.token2YesPrice,
            isV3: false,
            tickLower: 0,
            tickUpper: 0,
            fee: 0
        });
        
        // Pool 4: NO_token2/WXDAI
        uint256 token2NoAmount = (wxdaiAmount * 1e18) / prices.token2NoPrice;
        pools[3] = PoolLiquidity({
            token0: wxdaiAddress,
            token1: token2NoAddress,
            amount0: wxdaiAmount,
            amount1: token2NoAmount,
            initialPrice: prices.token2NoPrice,
            isV3: false,
            tickLower: 0,
            tickUpper: 0,
            fee: 0
        });
        
        return pools;
    }
    
    /**
     * @notice Calculates liquidity for v2 YES/YES and NO/NO pools
     * @param tokens Array of token data
     * @param prices Token prices
     * @return pools Array of v2 YES/YES and NO/NO pool liquidity data
     */
    function calculateV2YesNoPools(
        TokenData[] memory tokens,
        TokenPrices memory prices
    ) internal returns (PoolLiquidity[] memory) {
        console.log("Calculating v2 YES/YES and NO/NO pools...");
        
        // We need 2 pools: YES_token1/YES_token2, NO_token1/NO_token2
        PoolLiquidity[] memory pools = new PoolLiquidity[](2);
        
        // Find relevant tokens
        address token1YesAddress;
        address token1NoAddress;
        address token2YesAddress;
        address token2NoAddress;
        
        for (uint256 i = 0; i < tokens.length; i++) {
            if (keccak256(bytes(tokens[i].tokenType)) == keccak256(bytes("token1Yes"))) {
                token1YesAddress = tokens[i].tokenAddress;
            } else if (keccak256(bytes(tokens[i].tokenType)) == keccak256(bytes("token1No"))) {
                token1NoAddress = tokens[i].tokenAddress;
            } else if (keccak256(bytes(tokens[i].tokenType)) == keccak256(bytes("token2Yes"))) {
                token2YesAddress = tokens[i].tokenAddress;
            } else if (keccak256(bytes(tokens[i].tokenType)) == keccak256(bytes("token2No"))) {
                token2NoAddress = tokens[i].tokenAddress;
            }
        }
        
        // Calculate price ratio between YES tokens and between NO tokens
        uint256 yesTokensRatio = (prices.token1YesPrice * 1e18) / prices.token2YesPrice;
        uint256 noTokensRatio = (prices.token1NoPrice * 1e18) / prices.token2NoPrice;
        
        // Use balanced amounts for YES tokens pool
        uint256 baseYesAmount = 1e18; // 1 token with 18 decimals
        uint256 token1YesAmount = baseYesAmount;
        uint256 token2YesAmount = (token1YesAmount * 1e18) / yesTokensRatio;
        
        pools[0] = PoolLiquidity({
            token0: token1YesAddress,
            token1: token2YesAddress,
            amount0: token1YesAmount,
            amount1: token2YesAmount,
            initialPrice: yesTokensRatio,
            isV3: false,
            tickLower: 0,
            tickUpper: 0,
            fee: 0
        });
        
        // Use balanced amounts for NO tokens pool
        uint256 baseNoAmount = 1e18; // 1 token with 18 decimals
        uint256 token1NoAmount = baseNoAmount;
        uint256 token2NoAmount = (token1NoAmount * 1e18) / noTokensRatio;
        
        pools[1] = PoolLiquidity({
            token0: token1NoAddress,
            token1: token2NoAddress,
            amount0: token1NoAmount,
            amount1: token2NoAmount,
            initialPrice: noTokensRatio,
            isV3: false,
            tickLower: 0,
            tickUpper: 0,
            fee: 0
        });
        
        return pools;
    }
    
    /**
     * @notice Calculates liquidity for v3 pools with concentrated liquidity
     * @param tokens Array of token data
     * @param prices Token prices
     * @param token1Amount Token1 amount from config
     * @param token2Amount Token2 amount from config
     * @param priceRangeMultiplier Multiplier for price range (e.g., 1.2 for ±20%)
     * @return pools Array of v3 pool liquidity data
     */
    function calculateV3Pools(
        TokenData[] memory tokens,
        TokenPrices memory prices,
        uint256 token1Amount,
        uint256 token2Amount,
        uint256 priceRangeMultiplier
    ) internal returns (PoolLiquidity[] memory) {
        console.log("Calculating v3 pools with concentrated liquidity...");
        
        // We need 2 pools: YES_token1/YES_token2, NO_token1/NO_token2
        PoolLiquidity[] memory pools = new PoolLiquidity[](2);
        
        // Find relevant tokens
        address token1YesAddress;
        address token1NoAddress;
        address token2YesAddress;
        address token2NoAddress;
        
        for (uint256 i = 0; i < tokens.length; i++) {
            if (keccak256(bytes(tokens[i].tokenType)) == keccak256(bytes("token1Yes"))) {
                token1YesAddress = tokens[i].tokenAddress;
            } else if (keccak256(bytes(tokens[i].tokenType)) == keccak256(bytes("token1No"))) {
                token1NoAddress = tokens[i].tokenAddress;
            } else if (keccak256(bytes(tokens[i].tokenType)) == keccak256(bytes("token2Yes"))) {
                token2YesAddress = tokens[i].tokenAddress;
            } else if (keccak256(bytes(tokens[i].tokenType)) == keccak256(bytes("token2No"))) {
                token2NoAddress = tokens[i].tokenAddress;
            }
        }
        
        // Calculate price ratio between YES tokens and between NO tokens (token1 in terms of token0)
        uint256 yesTokensRatio = (prices.token1YesPrice * 1e18) / prices.token2YesPrice;
        uint256 noTokensRatio = (prices.token1NoPrice * 1e18) / prices.token2NoPrice;
        
        // Calculate tick ranges (±20% from spot price)
        (int24 yesTickLower, int24 yesTickUpper) = calculateTickRange(yesTokensRatio, priceRangeMultiplier);
        (int24 noTickLower, int24 noTickUpper) = calculateTickRange(noTokensRatio, priceRangeMultiplier);
        
        // V3 Pool 1: YES_token1/YES_token2
        pools[0] = PoolLiquidity({
            token0: token1YesAddress,
            token1: token2YesAddress,
            amount0: token1Amount,
            amount1: token2Amount,
            initialPrice: yesTokensRatio,
            isV3: true,
            tickLower: yesTickLower,
            tickUpper: yesTickUpper,
            fee: V3_FEE_TIER
        });
        
        // V3 Pool 2: NO_token1/NO_token2
        pools[1] = PoolLiquidity({
            token0: token1NoAddress,
            token1: token2NoAddress,
            amount0: token1Amount,
            amount1: token2Amount,
            initialPrice: noTokensRatio,
            isV3: true,
            tickLower: noTickLower,
            tickUpper: noTickUpper,
            fee: V3_FEE_TIER
        });
        
        return pools;
    }
    
    /**
     * @notice Calculates the tick range for v3 pools
     * @param price The price ratio with 18 decimals
     * @param multiplier The price range multiplier with 18 decimals (e.g., 1.2e18 for ±20%)
     * @return tickLower The lower tick of the range
     * @return tickUpper The upper tick of the range
     */
    function calculateTickRange(
        uint256 price,
        uint256 multiplier
    ) internal pure returns (int24 tickLower, int24 tickUpper) {
        // Calculate price bounds
        uint256 priceLower = (price * 1e18) / multiplier;
        uint256 priceUpper = (price * multiplier) / 1e18;
        
        // Convert prices to ticks
        // Using approximation for tick calculation
        int24 rawTickLower = int24(int256((log2(priceLower) * 1e18) / log2(1.0001e18)));
        int24 rawTickUpper = int24(int256((log2(priceUpper) * 1e18) / log2(1.0001e18)));
        
        // Round to nearest valid tick
        tickLower = roundToNearestSpacing(rawTickLower, 10); // Spacing of 10 for 0.1% fee tier
        tickUpper = roundToNearestSpacing(rawTickUpper, 10);
        
        // Ensure tickUpper is always greater than tickLower
        if (tickUpper <= tickLower) {
            // If our calculation resulted in inverted ticks, create a small range around the current price
            int24 midTick = roundToNearestSpacing(int24(int256((log2(price) * 1e18) / log2(1.0001e18))), 10);
            tickLower = midTick - 100 * 10; // 100 tick spacings below
            tickUpper = midTick + 100 * 10; // 100 tick spacings above
        }
        
        return (tickLower, tickUpper);
    }
    
    /**
     * @notice Rounds a tick to the nearest valid tick based on tick spacing
     * @param tick The tick to round
     * @param spacing The tick spacing
     * @return The rounded tick
     */
    function roundToNearestSpacing(int24 tick, int24 spacing) internal pure returns (int24) {
        int24 remainder = tick % spacing;
        if (remainder < 0) {
            remainder += spacing;
        }
        if (remainder <= spacing / 2) {
            return tick - remainder;
        } else {
            return tick + (spacing - remainder);
        }
    }
    
    /**
     * @notice Calculates log base 2 of a number
     * @param x The number to calculate log2
     * @return The log base 2 with 18 decimals precision
     */
    function log2(uint256 x) internal pure returns (uint256) {
        // Binary search for the integer part
        uint256 n = 0;
        uint256 result = 0;
        
        // Find the highest bit
        if (x >= 2**128) { x >>= 128; n += 128; }
        if (x >= 2**64) { x >>= 64; n += 64; }
        if (x >= 2**32) { x >>= 32; n += 32; }
        if (x >= 2**16) { x >>= 16; n += 16; }
        if (x >= 2**8) { x >>= 8; n += 8; }
        if (x >= 2**4) { x >>= 4; n += 4; }
        if (x >= 2**2) { x >>= 2; n += 2; }
        if (x >= 2**1) { x >>= 1; n += 1; }
        
        // Integer part with 18 decimals precision
        result = n * 1e18;
        
        // Fractional part approximation (x is now in [1, 2))
        if (x > 1) {
            uint256 y = x;
            uint256 precision = 1e18;
            
            // Taylor series approximation for fractional part
            // log2(1+z) ≈ z - z^2/2 + z^3/3 - ...
            uint256 z = ((y - 1e18) * 1e18) / (y + 1e18);
            uint256 z2 = (z * z) / 1e18;
            
            uint256 term = z;
            result += term;
            
            term = (z2 * 1e18) / (2 * 1e18);
            result -= term;
            
            term = (z2 * z) / (3 * 1e18 * 1e18);
            result += term;
            
            term = (z2 * z2) / (4 * 1e18 * 1e18);
            result -= term;
        }
        
        return result;
    }
    
    /**
     * @notice Logs pool liquidity information
     * @param pools Array of pool liquidity data
     */
    function logPoolLiquidity(PoolLiquidity[] memory pools) internal view {
        console.log("=== Pool Liquidity Summary ===");
        console.log("Total number of pools: %d", pools.length);
        
        for (uint256 i = 0; i < pools.length; i++) {
            console.log("Pool %d:", i + 1);
            console.log("  Token0: %s", vm.toString(pools[i].token0));
            console.log("  Token1: %s", vm.toString(pools[i].token1));
            console.log("  Amount0: %s", vm.toString(pools[i].amount0));
            console.log("  Amount1: %s", vm.toString(pools[i].amount1));
            console.log("  Initial Price: %s", vm.toString(pools[i].initialPrice));
            console.log("  Pool Type: %s", pools[i].isV3 ? "V3" : "V2");
            
            if (pools[i].isV3) {
                console.log("  Tick Lower: %d", pools[i].tickLower);
                console.log("  Tick Upper: %d", pools[i].tickUpper);
                console.log("  Fee: %d", pools[i].fee);
            }
            
            console.log("------------------------------");
        }
    }
} 