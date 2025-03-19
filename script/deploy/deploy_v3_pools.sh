#!/bin/bash

# Set script to exit immediately if any command fails
set -e

# Load environment variables
if [ -f ".env" ]; then
  source .env
else
  echo "Error: .env file not found."
  exit 1
fi

# Check if required environment variables are set
if [ -z "$PROPOSAL_ADDRESS" ]; then
  echo "Error: PROPOSAL_ADDRESS must be set in .env file"
  exit 1
fi

if [ -z "$SUSHI_V3_FACTORY" ]; then
  echo "Error: SUSHI_V3_FACTORY must be set in .env file"
  exit 1
fi

if [ -z "$SUSHI_V3_POSITION_MANAGER" ]; then
  echo "Error: SUSHI_V3_POSITION_MANAGER must be set in .env file"
  exit 1
fi

if [ -z "$RPC_URL" ]; then
  echo "Error: RPC_URL must be set in .env file"
  exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
  echo "Error: PRIVATE_KEY must be set in .env file"
  exit 1
fi

# Set pool configuration parameters (can be passed as command line arguments)
FEE_TIER=${1:-1000}  # Default to 0.1% fee tier (1000 = 0.1%)
TICK_LOWER=${2:--200}  # Default to -200 ticks (approximately -20% from spot price)
TICK_UPPER=${3:-200}   # Default to 200 ticks (approximately +20% from spot price)
AMOUNT0=${4:-1000000000000000000}  # Default to 1e18 (1 token with 18 decimals)
AMOUNT1=${5:-1000000000000000000}  # Default to 1e18 (1 token with 18 decimals)

# Export pool configuration as environment variables for the script
export FEE_TIER
export TICK_LOWER
export TICK_UPPER
export AMOUNT0
export AMOUNT1

echo "Deploying V3 pools for proposal: $PROPOSAL_ADDRESS"
echo "Using SushiSwap V3 Factory: $SUSHI_V3_FACTORY"
echo "Using SushiSwap V3 Position Manager: $SUSHI_V3_POSITION_MANAGER"
echo ""
echo "Pool Configuration:"
echo "- Fee Tier: $FEE_TIER"
echo "- Tick Lower: $TICK_LOWER"
echo "- Tick Upper: $TICK_UPPER"
echo "- Amount0: $AMOUNT0"
echo "- Amount1: $AMOUNT1"

# Run the Forge script
forge script script/proposal/DeployV3Pools.s.sol:DeployV3Pools \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  -vvv

echo "V3 Pool deployment completed" 