#!/bin/bash
# Test script for SushiSwap V2 and V3 pool deployment

set -e # Exit on error

echo "Testing SushiSwap pool deployment..."

# Ensure environment variables are loaded
if [ ! -f .env ]; then
    echo "ERROR: .env file not found. Please create it first."
    exit 1
fi

source .env

# Set parameters for test
CONFIG_FILE="script/config/proposal.json"
RPC_URL="${RPC_URL:-https://rpc.gnosischain.com}"

# Make sure the private key is set
if [ -z "$PRIVATE_KEY" ]; then
    echo "ERROR: PRIVATE_KEY environment variable not set"
    exit 1
fi

echo "=== Testing V2 and V3 Pool Deployment ==="
echo "Using configuration file: $CONFIG_FILE"
echo "Using RPC URL: $RPC_URL"

# Run the script in simulation mode to test deployment
echo "Running script in simulation mode..."
forge script script/proposal/FutarchyProposalLiquidity.s.sol:FutarchyProposalLiquidity --sig "run(string)" "$CONFIG_FILE" --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --ffi -vvv

echo "Pool deployment test completed successfully!" 