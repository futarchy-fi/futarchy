#!/bin/bash

# Test script for the Price Oracle implementation
# This script tests the ability to fetch token prices from the SushiSwap API

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the absolute path of the project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${BLUE}Testing Price Oracle Implementation${NC}"
echo -e "${BLUE}====================================${NC}"

# Create a test script directly in the script directory
TEST_SCRIPT="$PROJECT_ROOT/script/TestPriceOracle.s.sol"

cat > "$TEST_SCRIPT" << 'EOL'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/price-oracle/PriceOracleService.sol";

contract TestPriceOracle is Script {
    function run() external {
        // Common token addresses on Gnosis Chain
        address WXDAI = 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d;
        address WETH = 0x6A023CCd1ff6F2045C3309768eAd9E68F978f6e1;
        address USDC = 0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83;
        
        // Chain ID for Gnosis Chain
        uint256 chainId = 100;
        
        // Create price oracle service
        PriceOracleService priceOracle = new PriceOracleService();
        
        // Fetch price data
        PriceOracleService.ProposalPriceData memory priceData = 
            priceOracle.fetchProposalPriceData(chainId, WETH, USDC, WXDAI);
            
        // Basic validation (just to ensure we got some data)
        require(priceData.token1.usdPrice > 0, "Token1 USD price should be positive");
        require(priceData.token2.usdPrice > 0, "Token2 USD price should be positive");
        require(priceData.token1YesPrice > 0, "Token1 YES price should be positive");
        require(priceData.token2YesPrice > 0, "Token2 YES price should be positive");
        
        console.log("Price Oracle Test: SUCCESS");
    }
}
EOL

echo -e "${BLUE}Created test script${NC}"
echo -e "${BLUE}Running test...${NC}"

# Run the test script with FFI enabled
if ETHERSCAN_KEY=dummy forge script "$TEST_SCRIPT":TestPriceOracle --rpc-url ${RPC_URL:-https://rpc.ankr.com/gnosis} -vvv --ffi; then
    echo -e "${GREEN}Price Oracle Test: SUCCESS${NC}"
    # Clean up
    rm "$TEST_SCRIPT"
    exit 0
else
    echo -e "${RED}Price Oracle Test: FAILED${NC}"
    # Keep the file for debugging if the test fails
    echo -e "${RED}Test script kept at $TEST_SCRIPT for debugging${NC}"
    exit 1
fi 