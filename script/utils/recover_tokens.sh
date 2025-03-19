#!/bin/bash

# Script to recover ERC20 tokens from a UniswapV3PassthroughRouter contract

# Ensure we exit on any error
set -e

# Display usage instructions if insufficient arguments
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <router_address> <token_address>"
    echo "Example: $0 0x1234...abcd 0xabcd...1234"
    exit 1
fi

# Get input parameters
ROUTER_ADDRESS=$1
TOKEN_ADDRESS=$2

# Load .env file if it exists
if [ -f .env ]; then
    source .env
else
    echo "No .env file found. Make sure your PRIVATE_KEY is set in the environment."
fi

# Ensure PRIVATE_KEY is set
if [ -z "$PRIVATE_KEY" ]; then
    echo "PRIVATE_KEY environment variable is not set. Please set it before running this script."
    exit 1
fi

# Set environment variables for the Foundry script
export ROUTER_ADDRESS
export TOKEN_ADDRESS

# Run the Foundry script on Gnosis Chain
echo "Recovering tokens from router $ROUTER_ADDRESS on Gnosis Chain..."
forge script script/utils/RecoverTokens.s.sol:RecoverTokensScript \
    --rpc-url https://rpc.gnosischain.com \
    --broadcast \
    --verify

echo "Recovery operation completed!" 