// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IFutarchyProposal} from "../../src/interfaces/IFutarchyProposal.sol";
import {IERC20} from "../../src/interfaces/IERC20Extended.sol";
import {IERC20Extended} from "../../src/interfaces/IERC20Extended.sol";

/**
 * @title ExtractConditionalTokens
 * @notice Script to extract and validate conditional tokens from a futarchy proposal
 * @dev This script queries the proposal contract for outcome tokens and extracts metadata
 */
contract ExtractConditionalTokens is Script {
    // Structure for token metadata
    struct TokenData {
        uint256 index;        // Token index in the proposal
        address tokenAddress; // Token contract address
        string tokenType;     // Token type (token1Yes, token1No, token2Yes, token2No)
        string symbol;        // Token symbol
        uint8 decimals;       // Token decimals
        address collateral;   // Collateral token address
    }

    // Output data structure
    struct ExtractedTokens {
        address proposalAddress; // Address of the proposal contract
        TokenData[] tokens;      // Array of token data objects
    }

    // Token type identifiers
    string constant TOKEN1_YES = "token1Yes";
    string constant TOKEN1_NO = "token1No";
    string constant TOKEN2_YES = "token2Yes";
    string constant TOKEN2_NO = "token2No";

    /**
     * @notice Main entry point - extract tokens from a proposal by address
     * @param proposalAddress The address of the futarchy proposal
     * @return output Structured data containing all token information
     */
    function extractTokens(address proposalAddress) public returns (ExtractedTokens memory output) {
        console.log("Extracting conditional tokens from proposal at %s", addressToString(proposalAddress));
        
        // Initialize the proposal interface
        IFutarchyProposal proposal = IFutarchyProposal(proposalAddress);
        
        // Initialize output structure
        output.proposalAddress = proposalAddress;
        
        // Get number of outcomes (should be 4)
        uint256 numOutcomes = proposal.numOutcomes();
        console.log("Proposal has %d outcomes", numOutcomes);
        
        if (numOutcomes != 4) {
            console.log("ERROR: Expected 4 outcomes, but found %d", numOutcomes);
            revert("Invalid number of outcomes");
        }
        
        // Get collateral tokens
        address collateral1 = address(proposal.collateralToken1());
        address collateral2 = address(proposal.collateralToken2());
        
        console.log("Collateral token 1: %s", addressToString(collateral1));
        console.log("Collateral token 2: %s", addressToString(collateral2));
        
        // Initialize token array
        output.tokens = new TokenData[](numOutcomes);
        
        // Extract each token
        for (uint256 i = 0; i < numOutcomes; i++) {
            console.log("\nExtracting token for outcome %d:", i);
            
            // Get the wrapped token for this outcome
            (IERC20 wrapped1155, ) = proposal.wrappedOutcome(i);
            
            // Skip if token doesn't exist
            if (address(wrapped1155) == address(0)) {
                console.log("ERROR: Token for outcome %d not found", i);
                revert("Token not found");
            }
            
            // Get token metadata by casting to extended interface
            IERC20Extended extendedToken = IERC20Extended(address(wrapped1155));
            string memory symbol = extendedToken.symbol();
            uint8 decimals = extendedToken.decimals();
            
            console.log("Token address: %s", addressToString(address(wrapped1155)));
            console.log("Token symbol: %s", symbol);
            console.log("Token decimals: %d", decimals);
            
            // Determine token type based on index
            string memory tokenType;
            address collateral;
            
            if (i == 0) {
                tokenType = TOKEN1_YES;
                collateral = collateral1;
            } else if (i == 1) {
                tokenType = TOKEN1_NO;
                collateral = collateral1;
            } else if (i == 2) {
                tokenType = TOKEN2_YES;
                collateral = collateral2;
            } else if (i == 3) {
                tokenType = TOKEN2_NO;
                collateral = collateral2;
            }
            
            console.log("Token type: %s", tokenType);
            console.log("Collateral: %s", addressToString(collateral));
            
            // Store token data
            output.tokens[i] = TokenData({
                index: i,
                tokenAddress: address(wrapped1155),
                tokenType: tokenType,
                symbol: symbol,
                decimals: decimals,
                collateral: collateral
            });
        }
        
        console.log("\nSuccessfully extracted all conditional tokens");
        return output;
    }

    /**
     * @notice Generates a JSON representation of the extracted tokens
     * @param tokens The extracted token data
     * @return json The JSON string representation
     */
    function tokensToJson(ExtractedTokens memory tokens) public returns (string memory) {
        // Build JSON manually
        string memory json = string(abi.encodePacked(
            '{\n',
            '  "proposalAddress": "', addressToString(tokens.proposalAddress), '",\n',
            '  "tokens": [\n'
        ));
        
        // Add each token
        for (uint256 i = 0; i < tokens.tokens.length; i++) {
            TokenData memory token = tokens.tokens[i];
            
            json = string(abi.encodePacked(
                json,
                '    {\n',
                '      "index": ', vm.toString(token.index), ',\n',
                '      "address": "', addressToString(token.tokenAddress), '",\n',
                '      "type": "', token.tokenType, '",\n',
                '      "symbol": "', token.symbol, '",\n',
                '      "decimals": ', vm.toString(token.decimals), ',\n',
                '      "collateralToken": "', addressToString(token.collateral), '"\n',
                '    }', i < tokens.tokens.length - 1 ? ',\n' : '\n'
            ));
        }
        
        // Close JSON
        json = string(abi.encodePacked(json, '  ]\n}\n'));
        
        return json;
    }

    /**
     * @notice Main script entry point - extracts tokens and outputs JSON
     * @param proposalAddress The address of the futarchy proposal
     * @param outputFile Optional file path to save the JSON output (empty string to skip file output)
     */
    function run(address proposalAddress, string memory outputFile) public {
        console.log("Starting conditional token extraction for proposal: %s", addressToString(proposalAddress));
        
        // Extract tokens
        ExtractedTokens memory tokens = extractTokens(proposalAddress);
        
        // Convert to JSON
        string memory json = tokensToJson(tokens);
        
        // Output JSON
        console.log("\nJSON Output:");
        console.log(json);
        
        // Save to file if a path was provided
        if (bytes(outputFile).length > 0) {
            console.log("\nSaving output to file: %s", outputFile);
            vm.writeFile(outputFile, json);
            console.log("File saved successfully");
        }
    }
    
    /**
     * @notice Simplified entry point that doesn't save to file
     * @param proposalAddress The address of the futarchy proposal
     */
    function run(address proposalAddress) public {
        run(proposalAddress, "");
    }
    
    /**
     * @notice Converts an address to a string
     * @param addr The address to convert
     * @return str The address as a string
     */
    function addressToString(address addr) internal pure returns (string memory) {
        return vm.toString(addr);
    }
} 