#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print usage information
function print_usage {
  echo -e "${YELLOW}Usage:${NC}"
  echo -e "  $0 <proposal_address> [--output <output_file>]"
  echo ""
  echo -e "${YELLOW}Arguments:${NC}"
  echo -e "  proposal_address    The address of the futarchy proposal to extract tokens from"
  echo ""
  echo -e "${YELLOW}Options:${NC}"
  echo -e "  --output <file>     Save the JSON output to the specified file"
  echo ""
  echo -e "${YELLOW}Examples:${NC}"
  echo -e "  $0 0x123456789abcdef0123456789abcdef01234567"
  echo -e "  $0 0x123456789abcdef0123456789abcdef01234567 --output tokens.json"
}

# Check if help is requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  print_usage
  exit 0
fi

# Check if proposal address is provided
if [[ -z "$1" ]]; then
  echo -e "${RED}Error: No proposal address provided${NC}"
  print_usage
  exit 1
fi

# Extract proposal address
PROPOSAL_ADDRESS="$1"
shift

# Check for output file option
OUTPUT_FILE=""

if [[ "$1" == "--output" && -n "$2" ]]; then
  OUTPUT_FILE="$2"
  shift 2
fi

# Load environment variables if .env exists
if [[ -f ".env" ]]; then
  source .env
fi

# Default to localhost if RPC URL not set
RPC_URL=${RPC_URL:-http://localhost:8545}

echo -e "${GREEN}Extracting conditional tokens from proposal: ${PROPOSAL_ADDRESS}${NC}"
echo -e "${YELLOW}Using RPC URL: ${RPC_URL}${NC}"

# Main execution
if [[ "$OUTPUT_FILE" == "" ]]; then
    # Just print to stdout
    forge script script/utils/ExtractConditionalTokens.s.sol:ExtractConditionalTokens \
        --sig "extractTokens(address)" "$PROPOSAL_ADDRESS" \
        --rpc-url "$RPC_URL" \
        $VERBOSE_ARG
else
    # Save to file
    OUTPUT=$(forge script script/utils/ExtractConditionalTokens.s.sol:ExtractConditionalTokens \
        --sig "extractTokens(address)" "$PROPOSAL_ADDRESS" \
        --rpc-url "$RPC_URL" \
        $VERBOSE_ARG)
    
    if [ $? -eq 0 ]; then
        # Save the output to the specified file
        echo "$OUTPUT" > "${OUTPUT_FILE}"
        echo -e "${GREEN}Output saved to ${OUTPUT_FILE}${NC}"
    else
        echo -e "${RED}Error: Failed to extract tokens${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Token extraction completed!${NC}" 