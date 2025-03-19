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
if [ -z "$RPC_URL" ]; then
  echo "Error: RPC_URL must be set in .env file"
  exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
  echo "Error: PRIVATE_KEY must be set in .env file"
  exit 1
fi

if [ -z "$ETHERSCAN_API_KEY" ]; then
  echo "Error: ETHERSCAN_API_KEY must be set in .env file"
  exit 1
fi

echo "Deploying UniswapV3PassthroughRouter on Gnosis Chain"
echo "Using RPC URL: $RPC_URL"

# Run the Forge script to deploy the router
forge script script/deploy/DeployUniswapV3PassthroughRouter.s.sol:DeployUniswapV3PassthroughRouter \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --chain-id 100 \
  -vvv

echo "UniswapV3PassthroughRouter deployment and verification completed" 