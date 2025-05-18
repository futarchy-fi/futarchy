# SushiSwap V2 and V3 Pool Deployment Integration

## Overview & Goal

Enhance the existing Futarchy implementation by completing the SushiSwap v2 and v3 liquidity pool deployment portion in the `script/proposal/FutarchyProposalLiquidity.s.sol` script. This will enable automated deployment of liquidity pools for conditional tokens after a Futarchy proposal is created.

## Technical Context

The project already has:
- A proposal creation system (`createProposal` function in `FutarchyProposalLiquidity.s.sol`)
- Token extraction logic (`extractConditionalTokens` function in `FutarchyProposalLiquidity.s.sol`)
- Liquidity calculation engine (`src/liquidity/LiquidityCalculationEngine.sol`)
- V2 Pool deployment started but unfinished (`src/liquidity/V2PoolDeploymentEngine.sol`)

## Implementation Requirements

### 1. Complete the V2 Pool Deployment Engine

Enhance the existing `V2PoolDeploymentEngine.sol` to properly:

- Deploy all required SushiSwap v2 pools from the `PoolLiquidity[]` data structure
- Handle token approvals for all tokens before adding liquidity
- Add proper error handling and logging for deployment operations
- Implement pool validation logic to verify pools were created correctly

Key file: `src/liquidity/V2PoolDeploymentEngine.sol`

### 2. Create a V3 Pool Deployment Engine

Develop a new `V3PoolDeploymentEngine.sol` contract that:

- Handles concentrated liquidity pool deployment on SushiSwap v3
- Configures pools with the calculated tick ranges from LiquidityCalculationEngine
- Sets up the specified fee tier (0.1% = 1000 in Uniswap/SushiSwap v3 terms)
- Manages position creation with the SushiSwap V3 Position Manager

New file: `src/liquidity/V3PoolDeploymentEngine.sol`

### 3. Integrate Pool Deployment in the Main Script

Update the `FutarchyProposalLiquidity.s.sol` script to:

- Incorporate both V2 and V3 pool deployment after proposal creation
- Properly sequence the operations (create proposal → extract tokens → calculate liquidity → deploy pools)
- Handle errors at each stage with appropriate fallbacks
- Save all generated pool addresses and liquidity data to a structured JSON file

Key file: `script/proposal/FutarchyProposalLiquidity.s.sol`

## Detailed Technical Specifications

### V2 Pool Deployment Specifics

The V2 Pool Deployment Engine should handle 6 pools:
1. **4 Token-WXDAI pools**:
   - token1Yes/WXDAI
   - token1No/WXDAI
   - token2Yes/WXDAI
   - token2No/WXDAI
   
2. **2 Cross-token pools**:
   - token1Yes/token2Yes (YES/YES)
   - token1No/token2No (NO/NO)

Required interfaces:
- `ISushiswapV2Factory` (`src/interfaces/ISushiswapV2Factory.sol`) - For creating pairs
- `ISushiswapV2Router` (`src/interfaces/ISushiswapV2Router.sol`) - For adding liquidity
- `ISushiswapV2Pair` (`src/interfaces/ISushiswapV2Pair.sol`) - For checking pool state

Key methods to implement:
- `deployV2Pools(PoolLiquidity[] memory pools)` - Deploys all V2 pools
- `deployPool(PoolLiquidity memory pool)` - Deploys a single V2 pool

### V3 Pool Deployment Specifics

The V3 Pool Deployment Engine should handle 2 pools:
1. **2 Cross-token concentrated liquidity pools**:
   - token1Yes/token2Yes (YES/YES) with ±20% price range
   - token1No/token2No (NO/NO) with ±20% price range

Required interfaces:
- `ISushiswapV3Factory` (`src/interfaces/ISushiswapV3Factory.sol`) - For creating V3 pools 
- `ISushiswapV3PositionManager` (`src/interfaces/ISushiswapV3PositionManager.sol`) - For managing positions
- `ISushiswapV3Pool` (`src/interfaces/ISushiswapV3Pool.sol`) - For interacting with V3 pools

Key methods to implement:
- `deployV3Pools(PoolLiquidity[] memory pools)` - Deploys all V3 pools
- `deployPool(PoolLiquidity memory pool)` - Deploys a single V3 pool
- `addInitialPosition(PoolLiquidity memory pool, address poolAddress)` - Adds the initial position with concentrated liquidity

### Integration in Main Script

Add the following to `script/proposal/FutarchyProposalLiquidity.s.sol`:

1. In the `run(string memory configPath)` function:
   - After `createProposal()` and `extractConditionalTokens()`
   - Add calls to deploy V2 and V3 pools
   - Save results to a structured report

2. Implement functions:
   - `deployLiquidityPools(LiquidityCalculationEngine.PoolLiquidity[] memory pools)`
   - `savePoolDeploymentReport(address[] memory poolAddresses, LiquidityCalculationEngine.PoolLiquidity[] memory pools)`

## Environment Variables Required

Add the following to your `.env` file:
```
# SushiSwap Contract Addresses (Gnosis Chain)
SUSHISWAP_V2_FACTORY=0xc35DADB65012eC5796536bD9864eD8773aBc74C4
SUSHISWAP_V2_ROUTER=0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506
SUSHISWAP_V3_FACTORY=0x7A5a5684c7E92D1aA73CB0c9c8a945f0C9eCe505
SUSHISWAP_V3_POSITION_MANAGER=0x7A5a5684c7E92D1aA73CB0c9c8a945f0C9eCe505
WXDAI=0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d
```

## Testing Instructions

1. Create a simple test script to verify V2 and V3 pool deployment:
   ```
   script/test/test_pool_deployment.sh
   ```

2. Create a unit test for the V3 Pool Deployment Engine:
   ```
   test/V3PoolDeploymentEngine.t.sol
   ```

3. Run an integration test with the full workflow:
   ```
   source .env && forge script script/proposal/FutarchyProposalLiquidity.s.sol --sig "run(string)" "script/config/proposal.json" --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --ffi -vvv
   ```

## Deliverables

1. Enhanced `src/liquidity/V2PoolDeploymentEngine.sol`
2. New `src/liquidity/V3PoolDeploymentEngine.sol`
3. Updated `script/proposal/FutarchyProposalLiquidity.s.sol` with integrated deployment logic
4. New `test/V3PoolDeploymentEngine.t.sol` for testing V3 deployments
5. New `script/test/test_pool_deployment.sh` for local testing
6. Documentation updates in `.instructions/liquidity.md` reflecting the implementation details

## Timeline and Dependencies

This implementation should be completed after the Liquidity Calculation Engine is fully tested and operational. The V2 and V3 pool deployments depend on accurate liquidity calculations and price data. 
