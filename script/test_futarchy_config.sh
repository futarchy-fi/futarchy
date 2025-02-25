#!/bin/bash

# Test script for FutarchyProposalLiquidity configuration loading
set -e  # Exit on error

echo "Testing FutarchyProposalLiquidity configuration loading..."

# Create a temporary test script
TEST_SCRIPT="script/TestFutarchyConfig.s.sol"

cat > "$TEST_SCRIPT" << 'EOL'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

contract TestFutarchyConfig is Script {
    // Configuration structure for proposal parameters (copy from FutarchyProposalLiquidity)
    struct ProposalConfig {
        string name;                // Proposal name
        string question;            // The question being asked
        string category;            // Question category (e.g., "governance")
        string lang;                // Language code (e.g., "en")
        address collateralToken1;   // First collateral token address
        address collateralToken2;   // Second collateral token address
        uint256 minBond;            // Minimum bond for reality.eth
        uint32 openingTime;         // Question opening time (0 for immediate)
        LiquidityConfig liquidity;  // Liquidity configuration
    }

    // Configuration for liquidity parameters (copy from FutarchyProposalLiquidity)
    struct LiquidityConfig {
        uint256 wxdaiAmount;        // WXDAI amount per pool
        uint256 token1Amount;       // Token1 amount for liquidity
        uint256 token2Amount;       // Token2 amount for liquidity
    }

    function run() external {
        console.log("Testing FutarchyProposalLiquidity configuration loading...");
        
        // Load the JSON file
        string memory configPath = "script/config/minimal_proposal.json";
        string memory jsonContent = vm.readFile(configPath);
        console.log("Loaded JSON file: %s", configPath);
        
        // Extract individual fields first to verify they can be parsed
        console.log("\nExtracting individual fields:");
        
        bytes memory nameData = vm.parseJson(jsonContent, ".name");
        string memory name = abi.decode(nameData, (string));
        console.log("name: %s", name);
        
        bytes memory questionData = vm.parseJson(jsonContent, ".question");
        string memory question = abi.decode(questionData, (string));
        console.log("question: %s", question);
        
        bytes memory categoryData = vm.parseJson(jsonContent, ".category");
        string memory category = abi.decode(categoryData, (string));
        console.log("category: %s", category);
        
        bytes memory langData = vm.parseJson(jsonContent, ".lang");
        string memory lang = abi.decode(langData, (string));
        console.log("lang: %s", lang);
        
        bytes memory collateralToken1Data = vm.parseJson(jsonContent, ".collateralToken1");
        address collateralToken1 = abi.decode(collateralToken1Data, (address));
        console.log("collateralToken1: %s", vm.toString(collateralToken1));
        
        bytes memory collateralToken2Data = vm.parseJson(jsonContent, ".collateralToken2");
        address collateralToken2 = abi.decode(collateralToken2Data, (address));
        console.log("collateralToken2: %s", vm.toString(collateralToken2));
        
        bytes memory minBondData = vm.parseJson(jsonContent, ".minBond");
        uint256 minBond = abi.decode(minBondData, (uint256));
        console.log("minBond: %s", vm.toString(minBond));
        
        bytes memory openingTimeData = vm.parseJson(jsonContent, ".openingTime");
        uint32 openingTime = uint32(abi.decode(openingTimeData, (uint256)));
        console.log("openingTime: %s", vm.toString(openingTime));
        
        // Extract liquidity fields
        console.log("\nExtracting liquidity fields:");
        
        bytes memory wxdaiAmountData = vm.parseJson(jsonContent, ".liquidity.wxdaiAmount");
        uint256 wxdaiAmount = abi.decode(wxdaiAmountData, (uint256));
        console.log("wxdaiAmount: %s", vm.toString(wxdaiAmount));
        
        bytes memory token1AmountData = vm.parseJson(jsonContent, ".liquidity.token1Amount");
        uint256 token1Amount = abi.decode(token1AmountData, (uint256));
        console.log("token1Amount: %s", vm.toString(token1Amount));
        
        bytes memory token2AmountData = vm.parseJson(jsonContent, ".liquidity.token2Amount");
        uint256 token2Amount = abi.decode(token2AmountData, (uint256));
        console.log("token2Amount: %s", vm.toString(token2Amount));
        
        // Try constructing the ProposalConfig struct manually
        console.log("\nConstructing the ProposalConfig struct manually:");
        
        LiquidityConfig memory liquidityConfig = LiquidityConfig({
            wxdaiAmount: wxdaiAmount,
            token1Amount: token1Amount,
            token2Amount: token2Amount
        });
        
        ProposalConfig memory proposalConfig = ProposalConfig({
            name: name,
            question: question,
            category: category,
            lang: lang,
            collateralToken1: collateralToken1,
            collateralToken2: collateralToken2,
            minBond: minBond,
            openingTime: openingTime,
            liquidity: liquidityConfig
        });
        
        console.log("Successfully constructed ProposalConfig struct:");
        console.log("- name: %s", proposalConfig.name);
        console.log("- collateralToken1: %s", vm.toString(proposalConfig.collateralToken1));
        console.log("- wxdaiAmount: %s", vm.toString(proposalConfig.liquidity.wxdaiAmount));
        
        // Now try to parse the entire object at once
        console.log("\nTrying to parse and decode the entire object at once:");
        
        bytes memory parsedJson = vm.parseJson(jsonContent);
        console.log("JSON parsed successfully");
        
        try this.decodeFullConfig(parsedJson) returns (ProposalConfig memory config) {
            console.log("Successfully decoded full ProposalConfig:");
            console.log("- name: %s", config.name);
            console.log("- collateralToken1: %s", vm.toString(config.collateralToken1));
            console.log("- wxdaiAmount: %s", vm.toString(config.liquidity.wxdaiAmount));
        } catch Error(string memory reason) {
            console.log("Error decoding full ProposalConfig: %s", reason);
        } catch (bytes memory) {
            console.log("Unknown error decoding full ProposalConfig");
            // Try a different approach - build it from parts
            console.log("\nFallback approach: building from fields...");
            
            // Already done this above, just showing we could decode it field by field
        }
    }
    
    function decodeFullConfig(bytes memory data) external pure returns (ProposalConfig memory) {
        return abi.decode(data, (ProposalConfig));
    }
}
EOL

echo "Running test script..."

# Run the forge script with FFI and verbosity
forge script "$TEST_SCRIPT":TestFutarchyConfig --ffi -vvv

# Clean up
rm "$TEST_SCRIPT"

echo "Test completed, temporary files removed." 