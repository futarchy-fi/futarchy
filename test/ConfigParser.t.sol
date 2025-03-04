// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../script/proposal/FutarchyProposalLiquidity.s.sol";

/**
 * @title ConfigParserTest
 * @notice Comprehensive test suite for the configuration parsing functionality
 */
contract ConfigParserTest is Test {
    FutarchyProposalLiquidity public script;
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
        vm.setEnv("SUSHI_V3_POSITION_MANAGER", "0xb4315e873dbcf96ffd0acd8ea43f689d8c20fb30");
        vm.setEnv("WXDAI_ADDRESS", "0xe91d153e0b41518a2ce8dd3d7944fa863463a97d");
        vm.setEnv("PRIVATE_KEY", "");
        vm.setEnv("RPC_URL", "");
        
        // Initialize the script
        script = new FutarchyProposalLiquidity();
    }

    // Test 1: Verify loading a valid proposal configuration
    function testLoadProposalConfig() public {
        // Call the internal function through a public wrapper
        FutarchyProposalLiquidity.ProposalConfig memory config = script.exposed_loadProposalConfig(configPath);
        
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
        // Call the internal function through a public wrapper
        FutarchyProposalLiquidity.ProposalConfig[] memory configs = script.exposed_loadBatchProposalConfigs(batchConfigPath);
        
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
        // Call the internal function through a public wrapper
        FutarchyProposalLiquidity.EnvConfig memory config = script.exposed_loadEnvConfig();
        
        // Verify the loaded environment configuration matches expected values
        assertEq(config.futarchyFactory, 0xa6cB18FCDC17a2B44E5cAd2d80a6D5942d30a345);
        assertEq(config.sushiV2Factory, 0xc35DADB65012eC5796536bD9864eD8773aBc74C4);
        assertEq(config.sushiV2Router, 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
        assertEq(config.sushiV3Factory, 0x3e1b852F6Ad9D52E88Fc16D8c8Af7825ec2eA4Dd);
        assertEq(config.sushiV3PositionManager, 0xb4315e873dBcf96Ffd0acd8EA43f689D8c20fB30);
        assertEq(config.wxdai, 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);
        assertEq(config.privateKey, 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);
        assertEq(config.rpcUrl, "https://rpc.gnosischain.com");
    }

    // Test 4: Verify validation of a valid proposal configuration
    function testValidateProposalConfig_Valid() public {
        // Create a valid configuration
        FutarchyProposalLiquidity.LiquidityConfig memory liqConfig = FutarchyProposalLiquidity.LiquidityConfig({
            wxdaiAmount: 1 ether,
            token1Amount: 1 ether,
            token2Amount: 1 ether
        });
        
        FutarchyProposalLiquidity.ProposalConfig memory config = FutarchyProposalLiquidity.ProposalConfig({
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
        script.exposed_validateProposalConfig(config);
    }

    // Test 5: Verify validation fails with empty name
    function testValidateProposalConfig_EmptyName() public {
        // Create an invalid configuration (empty name)
        FutarchyProposalLiquidity.LiquidityConfig memory liqConfig = FutarchyProposalLiquidity.LiquidityConfig({
            wxdaiAmount: 1 ether,
            token1Amount: 1 ether,
            token2Amount: 1 ether
        });
        
        FutarchyProposalLiquidity.ProposalConfig memory config = FutarchyProposalLiquidity.ProposalConfig({
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
        script.exposed_validateProposalConfig(config);
    }

    // Test 6: Verify validation fails with empty question
    function testValidateProposalConfig_EmptyQuestion() public {
        // Create an invalid configuration (empty question)
        FutarchyProposalLiquidity.LiquidityConfig memory liqConfig = FutarchyProposalLiquidity.LiquidityConfig({
            wxdaiAmount: 1 ether,
            token1Amount: 1 ether,
            token2Amount: 1 ether
        });
        
        FutarchyProposalLiquidity.ProposalConfig memory config = FutarchyProposalLiquidity.ProposalConfig({
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
        script.exposed_validateProposalConfig(config);
    }

    // Test 7: Verify validation fails with same tokens
    function testValidateProposalConfig_SameTokens() public {
        // Create an invalid configuration (same tokens)
        FutarchyProposalLiquidity.LiquidityConfig memory liqConfig = FutarchyProposalLiquidity.LiquidityConfig({
            wxdaiAmount: 1 ether,
            token1Amount: 1 ether,
            token2Amount: 1 ether
        });
        
        FutarchyProposalLiquidity.ProposalConfig memory config = FutarchyProposalLiquidity.ProposalConfig({
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
        script.exposed_validateProposalConfig(config);
    }

    // Test 8: Verify validation fails with zero bond
    function testValidateProposalConfig_ZeroBond() public {
        // Create an invalid configuration (zero bond)
        FutarchyProposalLiquidity.LiquidityConfig memory liqConfig = FutarchyProposalLiquidity.LiquidityConfig({
            wxdaiAmount: 1 ether,
            token1Amount: 1 ether,
            token2Amount: 1 ether
        });
        
        FutarchyProposalLiquidity.ProposalConfig memory config = FutarchyProposalLiquidity.ProposalConfig({
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
        script.exposed_validateProposalConfig(config);
    }

    // Test 9: Verify validation fails with zero liquidity amount
    function testValidateProposalConfig_ZeroLiquidity() public {
        // Create an invalid configuration (zero liquidity)
        FutarchyProposalLiquidity.LiquidityConfig memory liqConfig = FutarchyProposalLiquidity.LiquidityConfig({
            wxdaiAmount: 0,  // Invalid: zero amount
            token1Amount: 1 ether,
            token2Amount: 1 ether
        });
        
        FutarchyProposalLiquidity.ProposalConfig memory config = FutarchyProposalLiquidity.ProposalConfig({
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
        script.exposed_validateProposalConfig(config);
    }

    // Test 10: Verify loading an invalid configuration file fails
    function testLoadInvalidProposalConfig() public {
        // This should revert with the specific error message
        vm.expectRevert("Collateral tokens must be different");
        script.exposed_loadProposalConfig(invalidConfigPath);
    }

    // Test 11: Verify loading a configuration with missing fields fails
    function testLoadMissingFieldsProposalConfig() public {
        // This should revert with the specific error message
        vm.expectRevert("Question cannot be empty");
        script.exposed_loadProposalConfig(missingFieldsConfigPath);
    }

    // Test 12: Verify validation of environment config with missing variables
    function testMissingEnvironmentVariables() public {
        // Set the environment variable to an empty string, which should be treated as non-existent
        vm.setEnv("FUTARCHY_FACTORY", "");
        
        // This should revert with the specific error message
        vm.expectRevert("FutarchyFactory address cannot be zero");
        script.exposed_loadEnvConfig();
    }

    // Test 13: Verify validation of environment config with invalid addresses
    function testInvalidEnvironmentAddresses() public {
        // Set an invalid address (zero address)
        vm.setEnv("SUSHI_V2_FACTORY", "0x0000000000000000000000000000000000000000");
        
        // This should revert with the specific error message
        vm.expectRevert("SushiSwap V2 Factory address cannot be zero");
        script.exposed_loadEnvConfig();
    }

    // Test 14: Verify validation of environment config with missing RPC URL
    function testMissingRpcUrl() public {
        // Clear the RPC URL
        vm.setEnv("RPC_URL", "");
        
        // This should revert with the specific error message
        vm.expectRevert("RPC URL cannot be empty");
        script.exposed_loadEnvConfig();
    }

    // Test 15: Verify validation of environment config with missing private key
    function testMissingPrivateKey() public {
        // Clear the private key
        vm.setEnv("PRIVATE_KEY", "");
        
        // This should revert with the specific error message
        vm.expectRevert("Private key cannot be zero");
        script.exposed_loadEnvConfig();
    }

    // Test 16: Verify handling of malformed JSON
    function testMalformedJson() public {
        // This should revert with a JSON parsing error
        vm.expectRevert();
        script.exposed_loadProposalConfig(malformedJsonPath);
    }

    // Test 17: Verify handling of non-existent file
    function testNonExistentFile() public {
        // This should revert with a file not found error
        vm.expectRevert();
        script.exposed_loadProposalConfig("test/fixtures/non_existent_file.json");
    }
} 