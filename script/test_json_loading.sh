#!/bin/bash

# Test script for JSON loading in forge script
set -e  # Exit on error

echo "Creating test Forge script for JSON loading..."

# Create a temporary test script
TEST_SCRIPT="script/TestJsonLoading.s.sol"

cat > "$TEST_SCRIPT" << 'EOL'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

contract TestJsonLoading is Script {
    // Simple struct for testing
    struct SimpleConfig {
        string name;
        string question;
        uint256 value;
    }

    function run() external {
        console.log("Testing JSON loading...");

        // Test with a simple string
        string memory simpleJson = '{"name":"Test","question":"Question?","value":123}';
        bytes memory parsed = vm.parseJson(simpleJson);
        
        console.log("Simple JSON parsed successfully");
        
        try this.decodeSimple(parsed) returns (SimpleConfig memory config) {
            console.log("Successfully decoded simple JSON:");
            console.log("  name: %s", config.name);
            console.log("  question: %s", config.question);
            console.log("  value: %d", config.value);
        } catch Error(string memory reason) {
            console.log("Error decoding simple JSON: %s", reason);
        } catch (bytes memory) {
            console.log("Unknown error decoding simple JSON");
        }
        
        // Test with an actual file
        console.log("\nTesting with file...");
        string memory jsonContent = vm.readFile("script/config/minimal_proposal.json");
        console.log("File content loaded");
        
        // Try parsing the file content
        bytes memory parsedFile;
        try vm.parseJson(jsonContent) returns (bytes memory result) {
            parsedFile = result;
            console.log("File JSON parsed successfully");
        } catch Error(string memory reason) {
            console.log("Error parsing file JSON: %s", reason);
            return;
        } catch (bytes memory) {
            console.log("Unknown error parsing file JSON");
            return;
        }
        
        // Just test that we can extract a string field
        try vm.parseJson(jsonContent, ".name") returns (bytes memory nameData) {
            string memory name = abi.decode(nameData, (string));
            console.log("Successfully extracted name field: %s", name);
        } catch Error(string memory reason) {
            console.log("Error extracting name field: %s", reason);
        } catch (bytes memory) {
            console.log("Unknown error extracting name field");
        }
    }
    
    function decodeSimple(bytes memory data) external pure returns (SimpleConfig memory) {
        return abi.decode(data, (SimpleConfig));
    }
}
EOL

# Make it executable
chmod +x "$TEST_SCRIPT"

echo "Running test script..."

# Run the forge script with FFI and verbosity
forge script "$TEST_SCRIPT":TestJsonLoading --ffi -vvv

# Clean up
rm "$TEST_SCRIPT"

echo "Test completed, temporary files removed." 