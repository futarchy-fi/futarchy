// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IFutarchyFactory} from "../../src/interfaces/IFutarchyFactory.sol";
import {IERC20} from "../../src/interfaces/IERC20Extended.sol";
import {IERC20Extended} from "../../src/interfaces/IERC20Extended.sol";
import {PriceOracleService} from "../../src/price-oracle/PriceOracleService.sol";
import {LiquidityCalculationEngine} from "../../src/liquidity/LiquidityCalculationEngine.sol";
import {V2PoolDeploymentEngine} from "../../src/liquidity/V2PoolDeploymentEngine.sol";
import {V3PoolDeploymentEngine} from "../../src/liquidity/V3PoolDeploymentEngine.sol";
import {IFutarchyProposal} from "../../src/interfaces/IFutarchyProposal.sol";

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
        address sushiV3PositionManager; // SushiSwap V3 position manager address
        address wxdai;              // WXDAI token address
        uint256 privateKey;         // Private key for transactions
        string rpcUrl;              // RPC URL for Gnosis Chain
    }

    // Main script variables
    ProposalConfig public proposalConfig;
    EnvConfig public envConfig;

    // Structure for deployed pools report
    struct PoolDeploymentReport {
        address proposalAddress;    // Proposal address
        address[] v2Pools;          // V2 pool addresses
        V3PoolInfo[] v3Pools;       // V3 pool information
    }

    // Structure for V3 pool info
    struct V3PoolInfo {
        address poolAddress;        // V3 pool address
        uint256 tokenId;            // NFT position ID
    }

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
        config.sushiV3PositionManager = vm.envAddress("SUSHI_V3_POSITION_MANAGER");
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
        require(config.sushiV3PositionManager != address(0), "SushiSwap V3 Position Manager address cannot be zero");
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
        
        // Step 1: Extract conditional tokens
        LiquidityCalculationEngine.TokenData[] memory tokens = extractConditionalTokens(proposalAddress);
        
        // Step 2: Calculate liquidity
        LiquidityCalculationEngine.PoolLiquidity[] memory poolLiquidity = calculateLiquidity(tokens, proposalConfig);
        
        // Step 3: Deploy V2 pools
        address[] memory v2Pools = deployV2Pools(poolLiquidity);
        
        // Step 4: Deploy V3 pools
        (address[] memory v3PoolAddresses, uint256[] memory v3TokenIds) = deployV3Pools(poolLiquidity);
        
        // Step 5: Save deployment report
        savePoolDeploymentReport(proposalAddress, v2Pools, v3PoolAddresses, v3TokenIds);
        
        console.log("Futarchy proposal creation and liquidity deployment completed successfully.");
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
            
            // Step 1: Extract conditional tokens
            LiquidityCalculationEngine.TokenData[] memory tokens = extractConditionalTokens(proposalAddress);
            
            // Step 2: Calculate liquidity
            LiquidityCalculationEngine.PoolLiquidity[] memory poolLiquidity = calculateLiquidity(tokens, proposalConfig);
            
            // Step 3: Deploy V2 pools
            address[] memory v2Pools = deployV2Pools(poolLiquidity);
            
            // Step 4: Deploy V3 pools
            (address[] memory v3PoolAddresses, uint256[] memory v3TokenIds) = deployV3Pools(poolLiquidity);
            
            // Step 5: Save deployment report
            savePoolDeploymentReport(proposalAddress, v2Pools, v3PoolAddresses, v3TokenIds);
            
            console.log("Completed processing proposal %d", i + 1);
        }
        
        console.log("Batch processing completed successfully.");
    }

    /**
     * @notice Extracts conditional tokens from a proposal
     * @param proposalAddress The address of the proposal
     * @return tokenData Array of token data
     */
    function extractConditionalTokens(address proposalAddress) internal returns (LiquidityCalculationEngine.TokenData[] memory) {
        // Create array to store token data
        LiquidityCalculationEngine.TokenData[] memory tokens = new LiquidityCalculationEngine.TokenData[](4);
        
        // Access the proposal directly
        console.log("Accessing proposal contract at %s", addressToString(proposalAddress));
        
        // Initialize proposal interface
        IFutarchyProposal proposal = IFutarchyProposal(proposalAddress);
        
        // Get collateral tokens
        address collateral1 = address(proposal.collateralToken1());
        address collateral2 = address(proposal.collateralToken2());
        
        console.log("Collateral token 1: %s", addressToString(collateral1));
        console.log("Collateral token 2: %s", addressToString(collateral2));
        
        // Types for tokens
        string[4] memory tokenTypes = ["token1Yes", "token1No", "token2Yes", "token2No"];
        
        // Extract tokens for each outcome
        for (uint256 i = 0; i < 4; i++) {
            console.log("\nExtracting token for outcome %d:", i);
            
            // Get the wrapped token for this outcome
            (IERC20 wrapped1155, ) = proposal.wrappedOutcome(i);
            
            address tokenAddress = address(wrapped1155);
            
            // Skip if token doesn't exist
            if (tokenAddress == address(0)) {
                console.log("ERROR: Token for outcome %d not found", i);
                revert("Token not found");
            }
            
            // Get token metadata by casting to extended interface
            IERC20Extended extendedToken = IERC20Extended(tokenAddress);
            string memory symbol = extendedToken.symbol();
            uint8 decimals = extendedToken.decimals();
            
            console.log("Token address: %s", addressToString(tokenAddress));
            console.log("Token symbol: %s", symbol);
            console.log("Token decimals: %d", decimals);
            
            // Determine collateral based on index
            address collateral = i < 2 ? collateral1 : collateral2;
            
            // Store token data
            tokens[i] = LiquidityCalculationEngine.TokenData({
                tokenAddress: tokenAddress,
                tokenType: tokenTypes[i],
                symbol: symbol,
                decimals: decimals,
                collateralToken: collateral
            });
            
            console.log("Token type: %s", tokenTypes[i]);
            console.log("Collateral: %s", addressToString(collateral));
        }
        
        console.log("\nSuccessfully extracted all conditional tokens");
        
        // Don't save to JSON file, just return the tokens array
        return tokens;
    }

    /**
     * @notice Calculates liquidity for all pools
     * @param tokens Array of token data
     * @param config Proposal configuration
     * @return pools Array of pool liquidity data
     */
    function calculateLiquidity(
        LiquidityCalculationEngine.TokenData[] memory tokens,
        ProposalConfig memory config
    ) internal returns (LiquidityCalculationEngine.PoolLiquidity[] memory) {
        console.log("Calculating liquidity for all pools...");
        
        // Initialize the liquidity calculation engine
        LiquidityCalculationEngine engine = new LiquidityCalculationEngine();
        
        // Initialize the price oracle service
        PriceOracleService priceOracle = new PriceOracleService();
        
        // Find token addresses for price fetching
        address token1Address;
        address token2Address;
        
        for (uint256 i = 0; i < tokens.length; i++) {
            if (keccak256(bytes(tokens[i].tokenType)) == keccak256(bytes("token1Yes"))) {
                token1Address = tokens[i].collateralToken;
            } else if (keccak256(bytes(tokens[i].tokenType)) == keccak256(bytes("token2Yes"))) {
                token2Address = tokens[i].collateralToken;
            }
        }
        
        // Fetch price data for tokens
        uint256 chainId = getChainId();
        console.log("Fetching price data for collateral tokens on chain ID: %d", chainId);
        
        PriceOracleService.ProposalPriceData memory priceData =
            priceOracle.fetchProposalPriceData(
                chainId,
                token1Address,
                token2Address,
                envConfig.wxdai
            );
        
        // Create liquidity config from proposal config
        LiquidityCalculationEngine.LiquidityConfig memory liquidityConfig = 
            LiquidityCalculationEngine.LiquidityConfig({
                wxdaiAmount: config.liquidity.wxdaiAmount,
                token1Amount: config.liquidity.token1Amount,
                token2Amount: config.liquidity.token2Amount
            });
        
        // Calculate liquidity for all pools
        LiquidityCalculationEngine.PoolLiquidity[] memory pools = 
            engine.calculateAllPoolLiquidity(tokens, priceData, liquidityConfig);
        
        console.log("Liquidity calculation completed for %d pools", pools.length);
        
        // Don't save results to file, just return the pools array
        return pools;
    }

    /**
     * @notice Gets the current chain ID
     * @return chainId The chain ID
     */
    function getChainId() internal view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
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

    /**
     * @notice Deploys SushiSwap V2 pools for WXDAI paired with YES and NO tokens
     * @param pools Array of pool liquidity data
     * @return pairAddresses Array of deployed pool addresses
     */
    function deployV2Pools(
        LiquidityCalculationEngine.PoolLiquidity[] memory pools
    ) internal returns (address[] memory pairAddresses) {
        console.log("Deploying V2 pools...");
        
        // Initialize the V2 pool deployment engine
        V2PoolDeploymentEngine deploymentEngine = new V2PoolDeploymentEngine(
            envConfig.sushiV2Factory,
            envConfig.sushiV2Router,
            envConfig.wxdai
        );
        
        // Initialize array for pair addresses
        pairAddresses = new address[](pools.length);
        
        // Start broadcasting transactions
        vm.startBroadcast(envConfig.privateKey);
        
        // Deploy each V2 pool
        for (uint256 i = 0; i < pools.length; i++) {
            // Skip V3 pools
            if (pools[i].isV3) {
                console.log("Skipping V3 pool at index %d (will be processed later)", i);
                continue;
            }
            
            try deploymentEngine.deployPool(pools[i]) returns (address pair, uint256 liquidity) {
                pairAddresses[i] = pair;
                console.log("Successfully deployed V2 pool %d at address %s with %s liquidity", 
                    i, addressToString(pair), vm.toString(liquidity));
            } catch Error(string memory reason) {
                console.log("Error deploying V2 pool %d: %s", i, reason);
            } catch {
                console.log("Unknown error deploying V2 pool %d", i);
            }
        }
        
        // Stop broadcasting transactions
        vm.stopBroadcast();
        
        return pairAddresses;
    }

    /**
     * @notice Deploys SushiSwap V3 pools with concentrated liquidity
     * @param pools Array of pool liquidity data
     * @return poolAddresses Array of deployed pool addresses
     * @return tokenIds Array of NFT token IDs for the positions
     */
    function deployV3Pools(
        LiquidityCalculationEngine.PoolLiquidity[] memory pools
    ) internal returns (address[] memory poolAddresses, uint256[] memory tokenIds) {
        console.log("Deploying V3 pools...");
        
        // Initialize the V3 pool deployment engine
        V3PoolDeploymentEngine deploymentEngine = new V3PoolDeploymentEngine(
            envConfig.sushiV3Factory,
            envConfig.sushiV3PositionManager
        );
        
        // Start broadcasting transactions
        vm.startBroadcast(envConfig.privateKey);
        
        // Deploy V3 pools
        (poolAddresses, tokenIds) = deploymentEngine.deployV3Pools(pools);
        
        // Stop broadcasting transactions
        vm.stopBroadcast();
        
        console.log("Successfully deployed %d V3 pools", poolAddresses.length);
        
        return (poolAddresses, tokenIds);
    }

    /**
     * @notice Saves the pool deployment report
     * @param proposalAddress The address of the proposal
     * @param v2Pools Array of V2 pool addresses
     * @param v3PoolAddresses Array of V3 pool addresses
     * @param v3TokenIds Array of V3 position NFT token IDs
     */
    function savePoolDeploymentReport(
        address proposalAddress,
        address[] memory v2Pools,
        address[] memory v3PoolAddresses,
        uint256[] memory v3TokenIds
    ) internal {
        console.log("Saving pool deployment report...");
        
        // Create and populate V3 pool info array
        V3PoolInfo[] memory v3Pools = new V3PoolInfo[](v3PoolAddresses.length);
        for (uint256 i = 0; i < v3PoolAddresses.length; i++) {
            v3Pools[i] = V3PoolInfo({
                poolAddress: v3PoolAddresses[i],
                tokenId: v3TokenIds[i]
            });
        }
        
        // Create pool deployment report
        PoolDeploymentReport memory report = PoolDeploymentReport({
            proposalAddress: proposalAddress,
            v2Pools: v2Pools,
            v3Pools: v3Pools
        });
        
        // Create JSON string for the report
        string memory reportJson = generateReportJson(report);
        
        // Save report to file
        string memory fileName = string(abi.encodePacked(
            "pool_deployment_",
            vm.toString(proposalAddress),
            ".json"
        ));
        
        vm.writeFile(fileName, reportJson);
        console.log("Pool deployment report saved to %s", fileName);
    }

    /**
     * @notice Generates a JSON string for the pool deployment report
     * @param report The pool deployment report structure
     * @return jsonString The generated JSON string
     */
    function generateReportJson(PoolDeploymentReport memory report) internal pure returns (string memory) {
        // Start with the opening braces
        string memory jsonString = "{";
        
        // Add proposal address
        jsonString = string(abi.encodePacked(
            jsonString,
            '"proposalAddress":"', vm.toString(report.proposalAddress), '",'
        ));
        
        // Add V2 pools array
        jsonString = string(abi.encodePacked(jsonString, '"v2Pools":['));
        for (uint256 i = 0; i < report.v2Pools.length; i++) {
            // Skip empty addresses
            if (report.v2Pools[i] == address(0)) continue;
            
            jsonString = string(abi.encodePacked(
                jsonString,
                '"', vm.toString(report.v2Pools[i]), '"'
            ));
            
            // Add comma if not the last element
            if (i < report.v2Pools.length - 1) {
                jsonString = string(abi.encodePacked(jsonString, ','));
            }
        }
        jsonString = string(abi.encodePacked(jsonString, '],'));
        
        // Add V3 pools array
        jsonString = string(abi.encodePacked(jsonString, '"v3Pools":['));
        for (uint256 i = 0; i < report.v3Pools.length; i++) {
            // Skip empty addresses
            if (report.v3Pools[i].poolAddress == address(0)) continue;
            
            jsonString = string(abi.encodePacked(
                jsonString,
                '{"poolAddress":"', vm.toString(report.v3Pools[i].poolAddress),
                '","tokenId":', vm.toString(report.v3Pools[i].tokenId),
                '}'
            ));
            
            // Add comma if not the last element
            if (i < report.v3Pools.length - 1) {
                jsonString = string(abi.encodePacked(jsonString, ','));
            }
        }
        jsonString = string(abi.encodePacked(jsonString, ']'));
        
        // Close the JSON object
        jsonString = string(abi.encodePacked(jsonString, '}'));
        
        return jsonString;
    }
} 