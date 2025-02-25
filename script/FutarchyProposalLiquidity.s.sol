// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

/**
 * @title FutarchyProposalLiquidity
 * @notice Script to create futarchy proposals and add liquidity to conditional token pools
 * @dev This script handles the entire process from proposal creation to liquidity provision
 */
contract FutarchyProposalLiquidity is Script {
    // Configuration structure for proposal parameters
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

    // Configuration for liquidity parameters
    struct LiquidityConfig {
        uint256 wxdaiAmount;        // WXDAI amount per pool
        uint256 token1Amount;       // Token1 amount for liquidity
        uint256 token2Amount;       // Token2 amount for liquidity
    }

    // Environment variables structure
    struct EnvConfig {
        address futarchyFactory;    // FutarchyFactory contract address
        address sushiV2Factory;     // SushiSwap V2 factory address
        address sushiV2Router;      // SushiSwap V2 router address
        address sushiV3Factory;     // SushiSwap V3 factory address
        address sushiV3Router;      // SushiSwap V3 router address
        address wxdai;              // WXDAI token address
        uint256 privateKey;         // Private key for transactions
        string rpcUrl;              // RPC URL for Gnosis Chain
    }

    // Main script variables
    ProposalConfig public proposalConfig;
    EnvConfig public envConfig;

    /**
     * @notice Loads and parses the proposal configuration from a JSON file
     * @param path The path to the JSON configuration file
     * @return config The parsed proposal configuration
     */
    function loadProposalConfig(string memory path) internal returns (ProposalConfig memory config) {
        // Read the file content
        string memory jsonContent = vm.readFile(path);
        
        // Parse the JSON
        bytes memory parsedJson = vm.parseJson(jsonContent);
        
        // Decode the JSON into our structure
        config = abi.decode(parsedJson, (ProposalConfig));
        
        // Validate the configuration
        validateProposalConfig(config);
        
        return config;
    }

    /**
     * @notice Loads and parses multiple proposal configurations from a JSON file
     * @param path The path to the JSON configuration file containing an array of proposals
     * @return configs Array of parsed proposal configurations
     */
    function loadBatchProposalConfigs(string memory path) internal returns (ProposalConfig[] memory configs) {
        // Read the file content
        string memory jsonContent = vm.readFile(path);
        
        // Parse the JSON array
        bytes memory parsedJson = vm.parseJson(jsonContent);
        
        // Decode the JSON into our structure
        configs = abi.decode(parsedJson, (ProposalConfig[]));
        
        // Validate each configuration
        for (uint256 i = 0; i < configs.length; i++) {
            validateProposalConfig(configs[i]);
        }
        
        return configs;
    }

    /**
     * @notice Validates the proposal configuration
     * @param config The proposal configuration to validate
     */
    function validateProposalConfig(ProposalConfig memory config) internal pure {
        require(bytes(config.name).length > 0, "Proposal name cannot be empty");
        require(bytes(config.question).length > 0, "Question cannot be empty");
        require(bytes(config.category).length > 0, "Category cannot be empty");
        require(bytes(config.lang).length > 0, "Language cannot be empty");
        require(config.collateralToken1 != address(0), "Collateral token 1 address cannot be zero");
        require(config.collateralToken2 != address(0), "Collateral token 2 address cannot be zero");
        require(config.collateralToken1 != config.collateralToken2, "Collateral tokens must be different");
        require(config.minBond > 0, "Minimum bond must be greater than zero");
        require(config.liquidity.wxdaiAmount > 0, "WXDAI amount must be greater than zero");
        require(config.liquidity.token1Amount > 0, "Token1 amount must be greater than zero");
        require(config.liquidity.token2Amount > 0, "Token2 amount must be greater than zero");
    }

    /**
     * @notice Loads environment variables
     * @return config The environment configuration
     */
    function loadEnvConfig() internal returns (EnvConfig memory config) {
        config.futarchyFactory = vm.envAddress("FUTARCHY_FACTORY");
        config.sushiV2Factory = vm.envAddress("SUSHI_V2_FACTORY");
        config.sushiV2Router = vm.envAddress("SUSHI_V2_ROUTER");
        config.sushiV3Factory = vm.envAddress("SUSHI_V3_FACTORY");
        config.sushiV3Router = vm.envAddress("SUSHI_V3_ROUTER");
        config.wxdai = vm.envAddress("WXDAI_ADDRESS");
        config.privateKey = vm.envUint("PRIVATE_KEY");
        config.rpcUrl = vm.envString("RPC_URL");
        
        // Validate environment config
        validateEnvConfig(config);
        
        return config;
    }

    /**
     * @notice Validates the environment configuration
     * @param config The environment configuration to validate
     */
    function validateEnvConfig(EnvConfig memory config) internal pure {
        require(config.futarchyFactory != address(0), "FutarchyFactory address cannot be zero");
        require(config.sushiV2Factory != address(0), "SushiSwap V2 Factory address cannot be zero");
        require(config.sushiV2Router != address(0), "SushiSwap V2 Router address cannot be zero");
        require(config.sushiV3Factory != address(0), "SushiSwap V3 Factory address cannot be zero");
        require(config.sushiV3Router != address(0), "SushiSwap V3 Router address cannot be zero");
        require(config.wxdai != address(0), "WXDAI address cannot be zero");
        require(config.privateKey != 0, "Private key cannot be zero");
        require(bytes(config.rpcUrl).length > 0, "RPC URL cannot be empty");
    }

    /**
     * @notice Main function to load all configuration
     * @param configPath Path to the JSON configuration
     * @return propConfig The proposal configuration
     * @return envConf The environment configuration
     */
    function loadConfiguration(string memory configPath) internal returns (
        ProposalConfig memory propConfig,
        EnvConfig memory envConf
    ) {
        console.log("Loading configuration from %s", configPath);
        
        // Load configurations
        propConfig = loadProposalConfig(configPath);
        envConf = loadEnvConfig();
        
        // Log loaded configuration summary
        console.log("Loaded proposal: %s", propConfig.name);
        console.log("Collateral Token 1: %s", addressToString(propConfig.collateralToken1));
        console.log("Collateral Token 2: %s", addressToString(propConfig.collateralToken2));
        console.log("Using FutarchyFactory: %s", addressToString(envConf.futarchyFactory));
        
        return (propConfig, envConf);
    }

    /**
     * @notice Main function to load batch configuration
     * @param configPath Path to the JSON configuration containing an array of proposals
     * @return proposalConfigs Array of proposal configurations
     * @return envConf The environment configuration
     */
    function loadBatchConfiguration(string memory configPath) internal returns (
        ProposalConfig[] memory proposalConfigs,
        EnvConfig memory envConf
    ) {
        console.log("Loading batch configuration from %s", configPath);
        
        // Load configurations
        proposalConfigs = loadBatchProposalConfigs(configPath);
        envConf = loadEnvConfig();
        
        // Log loaded configuration summary
        console.log("Loaded %d proposals", proposalConfigs.length);
        for (uint256 i = 0; i < proposalConfigs.length; i++) {
            console.log("Proposal %d: %s", i + 1, proposalConfigs[i].name);
        }
        console.log("Using FutarchyFactory: %s", addressToString(envConf.futarchyFactory));
        
        return (proposalConfigs, envConf);
    }

    /**
     * @notice Helper to convert address to string for logging
     */
    function addressToString(address addr) internal pure returns (string memory) {
        return vm.toString(addr);
    }

    /**
     * @notice Main entry point for the script with a single proposal
     * @param configPath Path to the proposal configuration JSON file
     */
    function run(string memory configPath) external {
        // Load configuration
        (proposalConfig, envConfig) = loadConfiguration(configPath);
        
        // TODO: Implement the rest of the steps:
        // 1. Contract interface integration
        // 2. Price oracle implementation
        // 3. Proposal creation
        // 4. Conditional token extraction
        // 5. Liquidity calculation
        // 6. v2 pool deployment
        // 7. v3 pool parameter calculation
        // 8. v3 pool deployment
        // 9. Validation and reporting
        
        console.log("Configuration loaded successfully. Implementation of remaining steps pending.");
    }

    /**
     * @notice Main entry point for the script with batch processing
     * @param configPath Path to the batch proposal configuration JSON file
     */
    function runBatch(string memory configPath) external {
        // Load batch configuration
        (ProposalConfig[] memory proposalConfigs, EnvConfig memory loadedEnvConfig) = loadBatchConfiguration(configPath);
        
        // Process each proposal
        for (uint256 i = 0; i < proposalConfigs.length; i++) {
            console.log("Processing proposal %d: %s", i + 1, proposalConfigs[i].name);
            
            // Set the current proposal config
            proposalConfig = proposalConfigs[i];
            envConfig = loadedEnvConfig;
            
            // TODO: Implement the rest of the steps for each proposal:
            // 1. Contract interface integration
            // 2. Price oracle implementation
            // 3. Proposal creation
            // 4. Conditional token extraction
            // 5. Liquidity calculation
            // 6. v2 pool deployment
            // 7. v3 pool parameter calculation
            // 8. v3 pool deployment
            // 9. Validation and reporting
            
            console.log("Proposal %d processed successfully.", i + 1);
        }
        
        console.log("Batch processing completed successfully.");
    }

    // Exposed functions for testing
    
    /**
     * @notice Exposed version of loadProposalConfig for testing
     * @param path The path to the JSON configuration file
     * @return config The parsed proposal configuration
     */
    function exposed_loadProposalConfig(string memory path) public returns (ProposalConfig memory) {
        return loadProposalConfig(path);
    }
    
    /**
     * @notice Exposed version of loadBatchProposalConfigs for testing
     * @param path The path to the JSON configuration file containing an array of proposals
     * @return configs Array of parsed proposal configurations
     */
    function exposed_loadBatchProposalConfigs(string memory path) public returns (ProposalConfig[] memory) {
        return loadBatchProposalConfigs(path);
    }
    
    /**
     * @notice Exposed version of validateProposalConfig for testing
     * @param config The proposal configuration to validate
     */
    function exposed_validateProposalConfig(ProposalConfig memory config) public pure {
        validateProposalConfig(config);
    }
    
    /**
     * @notice Exposed version of loadEnvConfig for testing
     * @return config The environment configuration
     */
    function exposed_loadEnvConfig() public returns (EnvConfig memory) {
        return loadEnvConfig();
    }
    
    /**
     * @notice Exposed version of validateEnvConfig for testing
     * @param config The environment configuration to validate
     */
    function exposed_validateEnvConfig(EnvConfig memory config) public pure {
        validateEnvConfig(config);
    }
} 