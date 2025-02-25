// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IFutarchyFactory} from "../src/interfaces/IFutarchyFactory.sol";
import {IERC20} from "../src/interfaces/IERC20Extended.sol";

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
        console.log("Loading proposal config from file: %s", path);
        
        // Read the file content
        string memory jsonContent = vm.readFile(path);
        
        // Extract each field individually to avoid decoding issues
        config.name = abi.decode(vm.parseJson(jsonContent, ".name"), (string));
        config.question = abi.decode(vm.parseJson(jsonContent, ".question"), (string));
        config.category = abi.decode(vm.parseJson(jsonContent, ".category"), (string));
        config.lang = abi.decode(vm.parseJson(jsonContent, ".lang"), (string));
        config.collateralToken1 = abi.decode(vm.parseJson(jsonContent, ".collateralToken1"), (address));
        config.collateralToken2 = abi.decode(vm.parseJson(jsonContent, ".collateralToken2"), (address));
        
        // Handle numeric values with care - they might be strings in the JSON
        string memory minBondStr = abi.decode(vm.parseJson(jsonContent, ".minBond"), (string));
        config.minBond = vm.parseUint(minBondStr);
        
        // Opening time is a uint32
        bytes memory openingTimeData = vm.parseJson(jsonContent, ".openingTime");
        config.openingTime = uint32(abi.decode(openingTimeData, (uint256)));
        
        // Handle liquidity config
        string memory wxdaiAmountStr = abi.decode(vm.parseJson(jsonContent, ".liquidity.wxdaiAmount"), (string));
        string memory token1AmountStr = abi.decode(vm.parseJson(jsonContent, ".liquidity.token1Amount"), (string));
        string memory token2AmountStr = abi.decode(vm.parseJson(jsonContent, ".liquidity.token2Amount"), (string));
        
        config.liquidity.wxdaiAmount = vm.parseUint(wxdaiAmountStr);
        config.liquidity.token1Amount = vm.parseUint(token1AmountStr);
        config.liquidity.token2Amount = vm.parseUint(token2AmountStr);
        
        // Log successful loading
        console.log("Successfully loaded proposal config: %s", config.name);
        console.log("Collateral Token 1: %s", addressToString(config.collateralToken1));
        console.log("Collateral Token 2: %s", addressToString(config.collateralToken2));
        
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
        console.log("Loading batch proposal configs from file: %s", path);
        
        // Read the file content
        string memory jsonContent = vm.readFile(path);
        
        // Get array length from JSON
        uint256 length = vm.parseJsonUint(jsonContent, ".length");
        console.log("Number of proposals in batch: %d", length);
        
        // Initialize array
        configs = new ProposalConfig[](length);
        
        // Load each proposal separately
        for (uint256 i = 0; i < length; i++) {
            string memory basePath = string(abi.encodePacked("[", vm.toString(i), "]"));
            
            // Extract proposal details field by field
            ProposalConfig memory config;
            
            // Extract base fields
            config.name = abi.decode(vm.parseJson(jsonContent, string(abi.encodePacked(basePath, ".name"))), (string));
            config.question = abi.decode(vm.parseJson(jsonContent, string(abi.encodePacked(basePath, ".question"))), (string));
            config.category = abi.decode(vm.parseJson(jsonContent, string(abi.encodePacked(basePath, ".category"))), (string));
            config.lang = abi.decode(vm.parseJson(jsonContent, string(abi.encodePacked(basePath, ".lang"))), (string));
            config.collateralToken1 = abi.decode(vm.parseJson(jsonContent, string(abi.encodePacked(basePath, ".collateralToken1"))), (address));
            config.collateralToken2 = abi.decode(vm.parseJson(jsonContent, string(abi.encodePacked(basePath, ".collateralToken2"))), (address));
            
            // Handle numeric values with care
            string memory minBondStr = abi.decode(vm.parseJson(jsonContent, string(abi.encodePacked(basePath, ".minBond"))), (string));
            config.minBond = vm.parseUint(minBondStr);
            
            bytes memory openingTimeData = vm.parseJson(jsonContent, string(abi.encodePacked(basePath, ".openingTime")));
            config.openingTime = uint32(abi.decode(openingTimeData, (uint256)));
            
            // Extract liquidity config
            string memory liquidityBase = string(abi.encodePacked(basePath, ".liquidity"));
            string memory wxdaiAmountStr = abi.decode(vm.parseJson(jsonContent, string(abi.encodePacked(liquidityBase, ".wxdaiAmount"))), (string));
            string memory token1AmountStr = abi.decode(vm.parseJson(jsonContent, string(abi.encodePacked(liquidityBase, ".token1Amount"))), (string));
            string memory token2AmountStr = abi.decode(vm.parseJson(jsonContent, string(abi.encodePacked(liquidityBase, ".token2Amount"))), (string));
            
            config.liquidity.wxdaiAmount = vm.parseUint(wxdaiAmountStr);
            config.liquidity.token1Amount = vm.parseUint(token1AmountStr);
            config.liquidity.token2Amount = vm.parseUint(token2AmountStr);
            
            // Validate and add to array
            validateProposalConfig(config);
            configs[i] = config;
            
            console.log("Loaded proposal %d: %s", i + 1, config.name);
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
     * @notice Creates a futarchy proposal using the factory contract
     * @param config The proposal configuration
     * @param env The environment configuration
     * @return proposalAddress The address of the created proposal
     */
    function createProposal(ProposalConfig memory config, EnvConfig memory env) internal returns (address proposalAddress) {
        console.log("Creating proposal: %s", config.name);
        
        // Set up the factory contract interface
        IFutarchyFactory factory = IFutarchyFactory(env.futarchyFactory);
        
        // Construct the proposal parameters from the configuration
        IFutarchyFactory.CreateProposalParams memory params = IFutarchyFactory.CreateProposalParams({
            marketName: config.name,
            collateralToken1: IERC20(config.collateralToken1),
            collateralToken2: IERC20(config.collateralToken2),
            category: config.category,
            lang: config.lang,
            minBond: config.minBond,
            openingTime: config.openingTime
        });
        
        // Start the transaction
        vm.startBroadcast(env.privateKey);
        
        // Create the proposal
        try factory.createProposal(params) returns (address newProposalAddress) {
            proposalAddress = newProposalAddress;
            console.log("Proposal created successfully at address: %s", addressToString(proposalAddress));
        } catch Error(string memory reason) {
            console.log("Error creating proposal: %s", reason);
            revert(reason);
        } catch (bytes memory) {
            string memory errorMessage = "Unknown error creating proposal";
            console.log(errorMessage);
            revert(errorMessage);
        }
        
        // End the transaction
        vm.stopBroadcast();
        
        // Validate the proposal address
        require(proposalAddress != address(0), "Failed to create proposal");
        
        return proposalAddress;
    }

    /**
     * @notice Main entry point for the script with a single proposal
     * @param configPath Path to the proposal configuration JSON file
     */
    function run(string memory configPath) external {
        // Load configuration
        (proposalConfig, envConfig) = loadConfiguration(configPath);
        
        // Create the proposal
        address proposalAddress = createProposal(proposalConfig, envConfig);
        
        console.log("Proposal created at: %s", addressToString(proposalAddress));
        
        // TODO: Implement the rest of the steps:
        // 1. Conditional token extraction
        // 2. Liquidity calculation
        // 3. v2 pool deployment
        // 4. v3 pool parameter calculation
        // 5. v3 pool deployment
        // 6. Validation and reporting
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
            
            // Create the proposal
            address proposalAddress = createProposal(proposalConfig, envConfig);
            console.log("Proposal %d created at: %s", i + 1, addressToString(proposalAddress));
            
            // TODO: Implement the rest of the steps for each proposal:
            // 1. Conditional token extraction
            // 2. Liquidity calculation
            // 3. v2 pool deployment
            // 4. v3 pool parameter calculation
            // 5. v3 pool deployment
            // 6. Validation and reporting
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