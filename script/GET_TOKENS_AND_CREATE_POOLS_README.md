# GetTokensAndCreatePools Script

This script helps you obtain conditional tokens from a Futarchy proposal using the FutarchyRouter and then creates SushiSwap V2 liquidity pools with those tokens.

## Prerequisites

1. A deployed Futarchy proposal contract
2. WXDAI tokens to use as collateral
3. Access to the SushiSwap V2 Factory and Router contracts

## Configuration

Update your `.env` file with the following variables:

```
# Required variables for the script
export PROPOSAL_ADDRESS=<address of the futarchy proposal>
export WXDAI_AMOUNT=1000000000000000000 # 1 WXDAI (adjust as needed)
```

The other required variables are already in your `.env` file:
- `FUTARCHY_ROUTER`
- `SUSHI_V2_FACTORY`
- `SUSHI_V2_ROUTER`
- `WXDAI_ADDRESS`
- `PRIVATE_KEY`

## Usage

Run the script with Forge:

```bash
source .env && forge script script/proposal/GetTokensAndCreatePools.s.sol --rpc-url $RPC_URL --broadcast
```

If you want to pass the proposal address directly rather than using the environment variable:

```bash
source .env && forge script script/proposal/GetTokensAndCreatePools.s.sol --rpc-url $RPC_URL --broadcast --sig "run(address)" <proposal_address>
```

## What the Script Does

1. **Configuration Loading**: Loads the necessary configuration from environment variables.
2. **Getting Conditional Tokens**: 
   - Approves WXDAI for the FutarchyRouter
   - Calls `splitPosition` on the FutarchyRouter to get conditional tokens
   - Retrieves token addresses and checks balances
3. **Preparing Pool Configurations**:
   - Creates configurations for each conditional token paired with WXDAI
   - Splits WXDAI evenly among pools
4. **Creating Pools**:
   - Initializes the V2PoolDeploymentEngine
   - For each conditional token:
     - Approves tokens for the engine
     - Deploys a pool with the conditional token and WXDAI
5. **Summary**: Provides a summary of the deployed pools

## Troubleshooting

- If pools fail to deploy, check the error messages in the console output
- Ensure you have sufficient WXDAI and that all addresses are correct
- Verify that you have approved enough tokens for the operations
- If you encounter issues with the V2PoolDeploymentEngine, check that the token approvals are sufficient 