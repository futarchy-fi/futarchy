// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/forge-std/src/Test.sol";

/**
 * @title StandaloneConfigParserTest
 * @notice Standalone test suite for the configuration parsing functionality
 */
contract StandaloneConfigParserTest is Test {
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

    string public configPath;
    string public batchConfigPath;
    string public invalidConfigPath;
    string public missingFieldsConfigPath;
    string public malformedJsonPath;

    function setUp() public {
        // Create a test configuration file with known values
        configPath = "test/fixtures/test_proposal.json";
        string memory jsonContent = '{"name":"Test Proposal","question":"Should we test this?","category":"test","lang":"en","collateralToken1":"0xe91d153e0b41518a2ce8dd3d7944fa863463a97d","collateralToken2":"0x4ECaBa5870353805a9F068101A40E0f32ed605C6","minBond":"1000000000000000000","openingTime":0,"liquidity":{"wxdaiAmount":"10000000000000000000","token1Amount":"10000000000000000000","token2Amount":"10000000000000000000"}}';
        
        // Create a batch test configuration file
        batchConfigPath = "test/fixtures/test_batch_proposals.json";
        string memory batchJsonContent = '[{"name":"Test Proposal 1","question":"Should we test this?","category":"test","lang":"en","collateralToken1":"0xe91d153e0b41518a2ce8dd3d7944fa863463a97d","collateralToken2":"0x4ECaBa5870353805a9F068101A40E0f32ed605C6","minBond":"1000000000000000000","openingTime":0,"liquidity":{"wxdaiAmount":"10000000000000000000","token1Amount":"10000000000000000000","token2Amount":"10000000000000000000"}},{"name":"Test Proposal 2","question":"Should we test that?","category":"test","lang":"en","collateralToken1":"0xe91d153e0b41518a2ce8dd3d7944fa863463a97d","collateralToken2":"0x4ECaBa5870353805a9F068101A40E0f32ed605C6","minBond":"1000000000000000000","openingTime":0,"liquidity":{"wxdaiAmount":"20000000000000000000","token1Amount":"20000000000000000000","token2Amount":"20000000000000000000"}}]';
        
        // Create an invalid configuration file (same tokens)
        invalidConfigPath = "test/fixtures/invalid_proposal.json";
        string memory invalidJsonContent = '{"name":"Invalid Proposal","question":"Is this valid?","category":"test","lang":"en","collateralToken1":"0xe91d153e0b41518a2ce8dd3d7944fa863463a97d","collateralToken2":"0xe91d153e0b41518a2ce8dd3d7944fa863463a97d","minBond":"1000000000000000000","openingTime":0,"liquidity":{"wxdaiAmount":"10000000000000000000","token1Amount":"10000000000000000000","token2Amount":"10000000000000000000"}}';
        
        // Create a configuration file with missing fields
        missingFieldsConfigPath = "test/fixtures/missing_fields_proposal.json";
        string memory missingFieldsJsonContent = '{"name":"Missing Fields","question":"","category":"test","lang":"en","collateralToken1":"0xe91d153e0b41518a2ce8dd3d7944fa863463a97d","collateralToken2":"0x4ECaBa5870353805a9F068101A40E0f32ed605C6","minBond":"1000000000000000000","openingTime":0,"liquidity":{"wxdaiAmount":"10000000000000000000","token1Amount":"10000000000000000000","token2Amount":"10000000000000000000"}}';
        
        // Create a malformed JSON file
        malformedJsonPath = "test/fixtures/malformed_json.json";
        string memory malformedJsonContent = '{"name":"Malformed JSON","question":"Is this valid?","category":"test","lang":"en","collateralToken1":"0xe91d153e0b41518a2ce8dd3d7944fa863463a97d","collateralToken2":"0x4ECaBa5870353805a9F068101A40E0f32ed605C6","minBond":"1000000000000000000","openingTime":0,"liquidity":{"wxdaiAmount":"10000000000000000000","token1Amount":"10000000000000000000","token2Amount":"10000000000000000000"';  // Missing closing braces
        
        // Create the fixtures directory if it doesn't exist
        vm.createDir("test/fixtures", true);
        
        // Write the test configuration files
        vm.writeFile(configPath, jsonContent);
        vm.writeFile(batchConfigPath, batchJsonContent);
        vm.writeFile(invalidConfigPath, invalidJsonContent);
        vm.writeFile(missingFieldsConfigPath, missingFieldsJsonContent);
        vm.writeFile(malformedJsonPath, malformedJsonContent);
        
        // Set up environment variables for testing
        vm.setEnv("FUTARCHY_FACTORY", "0xa6cb18fcdc17a2b44e5cad2d80a6d5942d30a345");
        vm.setEnv("SUSHI_V2_FACTORY", "0xc35dadb65012ec5796536bd9864ed8773abc74c4");
        vm.setEnv("SUSHI_V2_ROUTER", "0x1b02da8cb0d097eb8d57a175b88c7d8b47997506");
        vm.setEnv("SUSHI_V3_FACTORY", "0x3e1b852f6ad9d52e88fc16d8c8af7825ec2ea4dd");
        vm.setEnv("SUSHI_V3_ROUTER", "0xb4315e873dbcf96ffd0acd8ea43f689d8c20fb30");
        vm.setEnv("WXDAI_ADDRESS", "0xe91d153e0b41518a2ce8dd3d7944fa863463a97d");
        vm.setEnv("PRIVATE_KEY", "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef");
        vm.setEnv("RPC_URL", "https://rpc.gnosischain.com");
    }

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

    // Test 1: Verify loading a valid proposal configuration
    function testLoadProposalConfig() public {
        // Call the internal function
        ProposalConfig memory config = loadProposalConfig(configPath);
        
        // Verify the loaded configuration matches expected values
        assertEq(config.name, "Test Proposal");
        assertEq(config.question, "Should we test this?");
        assertEq(config.category, "test");
        assertEq(config.lang, "en");
        assertEq(config.collateralToken1, 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);
        assertEq(config.collateralToken2, 0x4ECaBa5870353805a9F068101A40E0f32ed605C6);
        assertEq(config.minBond, 1000000000000000000);
        assertEq(config.openingTime, 0);
        assertEq(config.liquidity.wxdaiAmount, 10000000000000000000);
        assertEq(config.liquidity.token1Amount, 10000000000000000000);
        assertEq(config.liquidity.token2Amount, 10000000000000000000);
    }

    // Test 2: Verify loading batch proposal configurations
    function testLoadBatchProposalConfigs() public {
        // Call the internal function
        ProposalConfig[] memory configs = loadBatchProposalConfigs(batchConfigPath);
        
        // Verify the number of loaded configurations
        assertEq(configs.length, 2);
        
        // Verify the first proposal
        assertEq(configs[0].name, "Test Proposal 1");
        assertEq(configs[0].question, "Should we test this?");
        assertEq(configs[0].category, "test");
        assertEq(configs[0].lang, "en");
        assertEq(configs[0].collateralToken1, 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);
        assertEq(configs[0].collateralToken2, 0x4ECaBa5870353805a9F068101A40E0f32ed605C6);
        assertEq(configs[0].minBond, 1000000000000000000);
        assertEq(configs[0].openingTime, 0);
        assertEq(configs[0].liquidity.wxdaiAmount, 10000000000000000000);
        assertEq(configs[0].liquidity.token1Amount, 10000000000000000000);
        assertEq(configs[0].liquidity.token2Amount, 10000000000000000000);
        
        // Verify the second proposal
        assertEq(configs[1].name, "Test Proposal 2");
        assertEq(configs[1].question, "Should we test that?");
        assertEq(configs[1].category, "test");
        assertEq(configs[1].lang, "en");
        assertEq(configs[1].collateralToken1, 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);
        assertEq(configs[1].collateralToken2, 0x4ECaBa5870353805a9F068101A40E0f32ed605C6);
        assertEq(configs[1].minBond, 1000000000000000000);
        assertEq(configs[1].openingTime, 0);
        assertEq(configs[1].liquidity.wxdaiAmount, 20000000000000000000);
        assertEq(configs[1].liquidity.token1Amount, 20000000000000000000);
        assertEq(configs[1].liquidity.token2Amount, 20000000000000000000);
    }

    // Test 3: Verify loading environment configuration
    function testLoadEnvConfig() public {
        // Call the internal function
        EnvConfig memory config = loadEnvConfig();
        
        // Verify the loaded environment configuration matches expected values
        assertEq(config.futarchyFactory, 0xa6cB18FCDC17a2B44E5cAd2d80a6D5942d30a345);
        assertEq(config.sushiV2Factory, 0xc35DADB65012eC5796536bD9864eD8773aBc74C4);
        assertEq(config.sushiV2Router, 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
        assertEq(config.sushiV3Factory, 0x3e1b852F6Ad9D52E88Fc16D8c8Af7825ec2eA4Dd);
        assertEq(config.sushiV3Router, 0xb4315e873dBcf96Ffd0acd8EA43f689D8c20fB30);
        assertEq(config.wxdai, 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);
        assertEq(config.privateKey, 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);
        assertEq(config.rpcUrl, "https://rpc.gnosischain.com");
    }

    // Test 4: Verify validation of a valid proposal configuration
    function testValidateProposalConfig_Valid() public {
        // Create a valid configuration
        LiquidityConfig memory liqConfig = LiquidityConfig({
            wxdaiAmount: 1 ether,
            token1Amount: 1 ether,
            token2Amount: 1 ether
        });
        
        ProposalConfig memory config = ProposalConfig({
            name: "Valid Proposal",
            question: "Is this valid?",
            category: "test",
            lang: "en",
            collateralToken1: address(1),
            collateralToken2: address(2),
            minBond: 1 ether,
            openingTime: 0,
            liquidity: liqConfig
        });
        
        // This should not revert
        validateProposalConfig(config);
    }

    // Test 5: Verify validation fails with empty name
    function testValidateProposalConfig_EmptyName() public {
        // Create an invalid configuration (empty name)
        LiquidityConfig memory liqConfig = LiquidityConfig({
            wxdaiAmount: 1 ether,
            token1Amount: 1 ether,
            token2Amount: 1 ether
        });
        
        ProposalConfig memory config = ProposalConfig({
            name: "",  // Invalid: empty name
            question: "Is this valid?",
            category: "test",
            lang: "en",
            collateralToken1: address(1),
            collateralToken2: address(2),
            minBond: 1 ether,
            openingTime: 0,
            liquidity: liqConfig
        });
        
        // This should revert with the specific error message
        vm.expectRevert("Proposal name cannot be empty");
        validateProposalConfig(config);
    }

    // Test 6: Verify validation fails with empty question
    function testValidateProposalConfig_EmptyQuestion() public {
        // Create an invalid configuration (empty question)
        LiquidityConfig memory liqConfig = LiquidityConfig({
            wxdaiAmount: 1 ether,
            token1Amount: 1 ether,
            token2Amount: 1 ether
        });
        
        ProposalConfig memory config = ProposalConfig({
            name: "Valid Name",
            question: "",  // Invalid: empty question
            category: "test",
            lang: "en",
            collateralToken1: address(1),
            collateralToken2: address(2),
            minBond: 1 ether,
            openingTime: 0,
            liquidity: liqConfig
        });
        
        // This should revert with the specific error message
        vm.expectRevert("Question cannot be empty");
        validateProposalConfig(config);
    }

    // Test 7: Verify validation fails with same tokens
    function testValidateProposalConfig_SameTokens() public {
        // Create an invalid configuration (same tokens)
        LiquidityConfig memory liqConfig = LiquidityConfig({
            wxdaiAmount: 1 ether,
            token1Amount: 1 ether,
            token2Amount: 1 ether
        });
        
        ProposalConfig memory config = ProposalConfig({
            name: "Invalid Tokens",
            question: "Is this valid?",
            category: "test",
            lang: "en",
            collateralToken1: address(1),
            collateralToken2: address(1),  // Invalid: same as token1
            minBond: 1 ether,
            openingTime: 0,
            liquidity: liqConfig
        });
        
        // This should revert with the specific error message
        vm.expectRevert("Collateral tokens must be different");
        validateProposalConfig(config);
    }

    // Test 8: Verify validation fails with zero bond
    function testValidateProposalConfig_ZeroBond() public {
        // Create an invalid configuration (zero bond)
        LiquidityConfig memory liqConfig = LiquidityConfig({
            wxdaiAmount: 1 ether,
            token1Amount: 1 ether,
            token2Amount: 1 ether
        });
        
        ProposalConfig memory config = ProposalConfig({
            name: "Zero Bond",
            question: "Is this valid?",
            category: "test",
            lang: "en",
            collateralToken1: address(1),
            collateralToken2: address(2),
            minBond: 0,  // Invalid: zero bond
            openingTime: 0,
            liquidity: liqConfig
        });
        
        // This should revert with the specific error message
        vm.expectRevert("Minimum bond must be greater than zero");
        validateProposalConfig(config);
    }

    // Test 9: Verify validation fails with zero liquidity amount
    function testValidateProposalConfig_ZeroLiquidity() public {
        // Create an invalid configuration (zero liquidity)
        LiquidityConfig memory liqConfig = LiquidityConfig({
            wxdaiAmount: 0,  // Invalid: zero amount
            token1Amount: 1 ether,
            token2Amount: 1 ether
        });
        
        ProposalConfig memory config = ProposalConfig({
            name: "Zero Liquidity",
            question: "Is this valid?",
            category: "test",
            lang: "en",
            collateralToken1: address(1),
            collateralToken2: address(2),
            minBond: 1 ether,
            openingTime: 0,
            liquidity: liqConfig
        });
        
        // This should revert with the specific error message
        vm.expectRevert("WXDAI amount must be greater than zero");
        validateProposalConfig(config);
    }

    // Test 10: Verify loading an invalid configuration file fails
    function testLoadInvalidProposalConfig() public {
        // This should revert with the specific error message
        vm.expectRevert("Collateral tokens must be different");
        loadProposalConfig(invalidConfigPath);
    }

    // Test 11: Verify loading a configuration with missing fields fails
    function testLoadMissingFieldsProposalConfig() public {
        // This should revert with the specific error message
        vm.expectRevert("Question cannot be empty");
        loadProposalConfig(missingFieldsConfigPath);
    }

    // Test 12: Verify validation of environment config with missing variables
    function testMissingEnvironmentVariables() public {
        // Clear the environment variables by setting to empty string
        vm.setEnv("FUTARCHY_FACTORY", "");
        
        // This should revert with the specific error message
        vm.expectRevert("FutarchyFactory address cannot be zero");
        loadEnvConfig();
    }

    // Test 13: Verify validation of environment config with invalid addresses
    function testInvalidEnvironmentAddresses() public {
        // Set an invalid address (zero address)
        vm.setEnv("SUSHI_V2_FACTORY", "0x0000000000000000000000000000000000000000");
        
        // This should revert with the specific error message
        vm.expectRevert("SushiSwap V2 Factory address cannot be zero");
        loadEnvConfig();
    }

    // Test 14: Verify validation of environment config with missing RPC URL
    function testMissingRpcUrl() public {
        // Clear the RPC URL by setting to empty string
        vm.setEnv("RPC_URL", "");
        
        // This should revert with the specific error message
        vm.expectRevert("RPC URL cannot be empty");
        loadEnvConfig();
    }

    // Test 15: Verify validation of environment config with missing private key
    function testMissingPrivateKey() public {
        // Clear the private key by setting to empty string
        vm.setEnv("PRIVATE_KEY", "");
        
        // This should revert with the specific error message
        vm.expectRevert("Private key cannot be zero");
        loadEnvConfig();
    }

    // Test 16: Verify handling of malformed JSON
    function testMalformedJson() public {
        // This should revert with a JSON parsing error
        vm.expectRevert();
        loadProposalConfig(malformedJsonPath);
    }

    // Test 17: Verify handling of non-existent file
    function testNonExistentFile() public {
        // This should revert with a file not found error
        vm.expectRevert();
        loadProposalConfig("test/fixtures/non_existent_file.json");
    }
} 