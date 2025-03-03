#!/bin/bash

# Script to deploy futarchy proposal to Gnosis Chain
set -e  # Exit on error

# Load environment variables
if [ ! -f .env ]; then
    echo "Error: .env file not found. Please create one based on the template."
    exit 1
fi

source .env

# Check required environment variables
if [ -z "$RPC_URL" ] || [ -z "$PRIVATE_KEY" ] || [ -z "$FUTARCHY_FACTORY" ]; then
    echo "Error: Required environment variables are missing in .env file."
    echo "Please ensure RPC_URL, PRIVATE_KEY, and FUTARCHY_FACTORY are set."
    exit 1
fi

# Default proposal config path
CONFIG_PATH="script/config/gnosis_test_proposal.json"

# Allow custom config path as argument
if [ "$1" != "" ]; then
    CONFIG_PATH=$1
fi

echo "Deploying proposal using config: $CONFIG_PATH"
echo "Using RPC URL: $RPC_URL"
echo "Using Futarchy Factory: $FUTARCHY_FACTORY"

# Run the script
echo "Running forge script with config: $CONFIG_PATH"
echo "Command: forge script script/proposal/FutarchyProposalLiquidity.s.sol:FutarchyProposalLiquidity \
  --sig \"run(string)\" \"$CONFIG_PATH\" \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --ffi \
  -vvv"

forge script script/proposal/FutarchyProposalLiquidity.s.sol:FutarchyProposalLiquidity \
  --sig "run(string)" "$CONFIG_PATH" \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --ffi \
  -vvv

echo "Deployment completed!" 