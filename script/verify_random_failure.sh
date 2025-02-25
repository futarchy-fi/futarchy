#!/bin/bash

# Script to verify the RandomFutarchyFailure.sol file

# Set colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Verifying RandomFutarchyFailure.sol file...${NC}"
echo "==============================================="

# Check if the file exists
if [ -f "src/FAO/RandomFutarchyFailure.sol" ]; then
    echo -e "${GREEN}✓ File exists: src/FAO/RandomFutarchyFailure.sol${NC}"
else
    echo -e "${RED}✗ File does not exist: src/FAO/RandomFutarchyFailure.sol${NC}"
    exit 1
fi

# Check file content
if grep -q "contract FutarchyRandomFailure" "src/FAO/RandomFutarchyFailure.sol"; then
    echo -e "${GREEN}✓ File contains FutarchyRandomFailure contract${NC}"
else
    echo -e "${RED}✗ File does not contain FutarchyRandomFailure contract${NC}"
    exit 1
fi

# Verify import in FutarchyOracle.sol
if grep -q "import \"./RandomFutarchyFailure.sol\"" "src/FAO/FutarchyOracle.sol"; then
    echo -e "${GREEN}✓ FutarchyOracle.sol imports RandomFutarchyFailure.sol${NC}"
else
    echo -e "${RED}✗ FutarchyOracle.sol does not import RandomFutarchyFailure.sol${NC}"
    exit 1
fi

echo -e "${GREEN}All checks passed successfully!${NC}"
echo "==============================================="
echo "The RandomFutarchyFailure.sol file has been successfully created and can be imported by FutarchyOracle.sol." 