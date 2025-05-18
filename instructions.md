# Step 6: Liquidity Calculation Engine - Implementation Plan

## Overview
The Liquidity Calculation Engine will determine optimal token amounts for creating balanced liquidity pools. It needs to calculate liquidity parameters for multiple pool types:
1. SushiSwap v2 pools for conditional tokens paired with WXDAI
2. SushiSwap v2 pools for YES/YES and NO/NO token pairs
3. SushiSwap v3 concentrated liquidity pools with specific price ranges

## Implementation Plan

### 1. File Structure
- `script/LiquidityCalculationEngine.s.sol` - Main script with calculation logic
- `script/calculate_liquidity.sh` - Shell wrapper for easy execution
- `src/utils/LiquidityMath.sol` - Library with reusable math functions
- `script/config/liquidity_params.json` - Configuration for liquidity parameters

### 2. Key Data Structures
```solidity
// Input configuration
struct LiquidityConfig {
    uint256 totalLiquidityUSD;     // Total USD value to deploy across all pools
    uint256 v2PoolPercentage;      // Percentage of liquidity for v2 pools (e.g., 80%)
    uint256 v3PoolPercentage;      // Percentage of liquidity for v3 pools (e.g., 20%)
    uint256 v2TokenWXDAIPercent;   // Percentage of v2 liquidity for token/WXDAI pools
    uint256 v2YesNoPercent;        // Percentage of v2 liquidity for YES/YES and NO/NO pools
    uint256 priceRangeMultiplier;  // Price range for v3 pools (e.g., 120 for 1.2x)
}

// Price data (from Step 3)
struct TokenPrices {
    uint256 token1Price;           // Price of token1 in WXDAI
    uint256 token2Price;           // Price of token2 in WXDAI
    uint256 yesTokenMultiplier;    // Multiplier for YES tokens (e.g., 0.5 for half price)
    uint256 noTokenMultiplier;     // Multiplier for NO tokens (e.g., 0.5 for half price)
}

// Output liquidity parameters
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
```

### 3. Core Functions

#### A. Load Required Data
```solidity
function loadTokenData(string memory jsonPath) internal returns (TokenData[] memory);
function loadPriceData() internal returns (TokenPrices memory);
function loadLiquidityConfig(string memory jsonPath) internal returns (LiquidityConfig memory);
```

#### B. Calculate Pool Allocations
```solidity
function calculatePoolAllocations(
    TokenData[] memory tokens,
    TokenPrices memory prices,
    LiquidityConfig memory config
) internal returns (PoolLiquidity[] memory);
```

#### C. Calculate V2 Pool Parameters
```solidity
function calculateV2TokenWXDAIPools(
    TokenData[] memory tokens,
    TokenPrices memory prices,
    uint256 liquidityUSD
) internal returns (PoolLiquidity[] memory);

function calculateV2YesNoPools(
    TokenData[] memory tokens,
    TokenPrices memory prices,
    uint256 liquidityUSD
) internal returns (PoolLiquidity[] memory);
```

#### D. Calculate V3 Pool Parameters
```solidity
function calculateV3Pools(
    TokenData[] memory tokens,
    TokenPrices memory prices,
    uint256 liquidityUSD,
    uint256 priceRangeMultiplier
) internal returns (PoolLiquidity[] memory);

function calculateTickRange(
    uint256 price,
    uint256 multiplier
) internal pure returns (int24 tickLower, int24 tickUpper);
```

### 4. Mathematical Considerations

- **Price Calculation for YES/NO Tokens**: 
  - YES tokens should be priced at approximately 0.5x (50%) of collateral token price
  - NO tokens should also be priced at approximately 0.5x (50%) of collateral token price
  - Sum of YES + NO should equal 1x collateral price

- **V2 Pool Liquidity**:
  - For token/WXDAI pools, use the square root formula: `sqrt(token_amount * wxdai_amount) = k`
  - Calculate amounts to ensure the price matches market expectations

- **V3 Concentrated Liquidity**:
  - Convert price ratios to tick ranges using: `tick = log(sqrt_price) / log(sqrt(1.0001))`
  - For 1.2x range, calculate: `current_tick ± log(sqrt(1.2)) / log(sqrt(1.0001))`
  - Concentrate liquidity within this narrower range for better capital efficiency

### 5. Implementation Tips

1. **Price Normalization**:
   - Always normalize all prices to 18 decimals for consistent math
   - When interacting with tokens, adjust for their actual decimals

2. **Avoid Division Before Multiplication**:
   - To prevent precision loss, multiply before dividing in calculations

3. **Safe Math**:
   - Use SafeMath or unchecked blocks appropriately (Solidity 0.8.x)
   - Watch for potential overflows in price calculations

4. **Testing Values**:
   - Start with simpler test cases (equal prices, same decimals)
   - Gradually add complexity with different token decimals and price ratios

5. **Configuration Parameters**:
   - Make liquidity distribution configurable (not hardcoded)
   - Allow for adjustment of price range multipliers

6. **Error Handling**:
   - Add validation for unreasonable values (extremely small/large prices)
   - Implement guard rails for minimum liquidity amounts

### 6. Testing Strategy

1. **Unit Tests**:
   - Test each calculation function independently
   - Verify math with known examples and expected outputs

2. **Mock Price Data**:
   - Create fixture with different price scenarios
   - Test calculations with various token price combinations

3. **Integration Testing**:
   - Verify the full calculation pipeline with real proposal data
   - Compare against manually calculated expected values

### 7. Output Format

The output should be a JSON structure like:
```json
{
  "proposalAddress": "0x6242AbA055957A63d682e9D3de3364ACB53D053A",
  "pools": [
    {
      "type": "v2TokenWXDAI",
      "token0": "0x177304d505eCA60E1aE0dAF1bba4A4c4181dB8Ad",
      "token0Symbol": "YES_GNO",
      "token1": "0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d",
      "token1Symbol": "WXDAI",
      "amount0": "1000000000000000000",
      "amount1": "500000000000000000",
      "initialPrice": "0.5"
    },
    // Additional pools...
  ]
}
```

### 8. Command Usage

```bash
# Calculate liquidity with default parameters
./script/calculate_liquidity.sh extracted_tokens.json

# Calculate with custom liquidity configuration
./script/calculate_liquidity.sh extracted_tokens.json --config custom_config.json

# Calculate and save output
./script/calculate_liquidity.sh extracted_tokens.json --output liquidity_params.json
```

## Next Steps After Implementation
1. Validate the calculations with a financial model (e.g., spreadsheet)
2. Ensure the total USD value is correctly allocated across all pools
3. Check that the initial prices match market expectations
4. Prepare for Step 7 (v2 Pool Deployment) using the calculated parameters 
