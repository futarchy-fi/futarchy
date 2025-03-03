#!/bin/bash

# Test script for the configuration parser

# Set colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Running Configuration Parser Tests...${NC}"
echo "==============================================="

# Create directory for test fixtures if it doesn't exist
mkdir -p test/fixtures

# Run the isolated tests that don't depend on external imports
forge test --match-path test/IsolatedConfigParser.t.sol -vv

# Check if tests passed
if [ $? -eq 0 ]; then
    echo -e "${GREEN}All tests passed successfully!${NC}"
    echo "==============================================="
    echo "Test Summary:"
    echo "- Verified configuration parser compiles successfully"
    echo "- Verified validation logic for proposal configuration"
else
    echo -e "${RED}Some tests failed. Please check the output above for details.${NC}"
fi 