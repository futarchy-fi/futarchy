// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../../src/liquidity/LiquidityCalculationEngine.sol";
import "../../src/price-oracle/PriceOracleService.sol";

/**
 * @title TestLiquidityCalculation
 * @notice Test script for validating the Liquidity Calculation Engine
 */
contract TestLiquidityCalculation is Script {
    using stdJson for string;

    function run() external {
        console.log("Testing Liquidity Calculation Engine...");
        
        // Initialize the liquidity calculation engine
        LiquidityCalculationEngine engine = new LiquidityCalculationEngine();
        
        // Initialize the price oracle service
        PriceOracleService priceOracle = new PriceOracleService();
        
        // 1. Load test token data from extracted_tokens.json if available, or create mock data
        LiquidityCalculationEngine.TokenData[] memory tokens;
        
        try vm.readFile("extracted_tokens.json") returns (string memory json) {
            console.log("Loading extracted tokens from file...");
            tokens = parseTokensFromJson(json);
        } catch {
            console.log("No extracted_tokens.json found, creating mock token data...");
            tokens = createMockTokenData();
        }
        
        // 2. Get price data
        uint256 chainId = vm.envUint("CHAIN_ID");
        address wxdaiAddress = vm.envAddress("WXDAI_ADDRESS");
        
        // For tokens, use either the extracted ones or mock collateral tokens
        address token1Address;
        address token2Address;
        
        if (tokens.length >= 2) {
            // Extract collateral tokens from the token data
            for (uint256 i = 0; i < tokens.length; i++) {
                if (keccak256(bytes(tokens[i].tokenType)) == keccak256(bytes("token1Yes"))) {
                    token1Address = tokens[i].collateralToken;
                } else if (keccak256(bytes(tokens[i].tokenType)) == keccak256(bytes("token2Yes"))) {
                    token2Address = tokens[i].collateralToken;
                }
            }
        } else {
            // Use mock addresses
            token1Address = 0x9C58BAcC331c9aa871AFD802DB6379a98e80CEdb; // GNO on Gnosis Chain
            token2Address = 0xaf204776c7245bF4147c2612BF6e5972Ee483701; // sDAI on Gnosis Chain
        }
        
        console.log("Fetching price data for tokens...");
        console.log("Token1: %s", vm.toString(token1Address));
        console.log("Token2: %s", vm.toString(token2Address));
        console.log("WXDAI: %s", vm.toString(wxdaiAddress));
        
        PriceOracleService.ProposalPriceData memory priceData =
            priceOracle.fetchProposalPriceData(chainId, token1Address, token2Address, wxdaiAddress);
        
        // 3. Create liquidity config
        LiquidityCalculationEngine.LiquidityConfig memory config = LiquidityCalculationEngine.LiquidityConfig({
            wxdaiAmount: 1e18, // 1 WXDAI per v2 pool
            token1Amount: 1e18, // 1 token1 for v3 pools
            token2Amount: 1e18  // 1 token2 for v3 pools
        });
        
        // 4. Calculate liquidity for all pools
        console.log("Calculating liquidity for all pools...");
        LiquidityCalculationEngine.PoolLiquidity[] memory pools = 
            engine.calculateAllPoolLiquidity(tokens, priceData, config);
        
        // 5. Validate the results
        validateResults(pools);
        
        console.log("Liquidity Calculation Test Completed Successfully!");
    }
    
    /**
     * @notice Parse token data from extracted_tokens.json
     * @param json The JSON content
     * @return tokens Array of token data
     */
    function parseTokensFromJson(string memory json) internal returns (LiquidityCalculationEngine.TokenData[] memory) {
        uint256 length = vm.parseJsonUint(json, ".tokens.length");
        LiquidityCalculationEngine.TokenData[] memory tokens = new LiquidityCalculationEngine.TokenData[](length);
        
        for (uint256 i = 0; i < length; i++) {
            string memory basePath = string.concat(".tokens[", vm.toString(i), "]");
            
            tokens[i] = LiquidityCalculationEngine.TokenData({
                tokenAddress: vm.parseJsonAddress(json, string.concat(basePath, ".address")),
                tokenType: vm.parseJsonString(json, string.concat(basePath, ".type")),
                symbol: vm.parseJsonString(json, string.concat(basePath, ".symbol")),
                decimals: uint8(vm.parseJsonUint(json, string.concat(basePath, ".decimals"))),
                collateralToken: vm.parseJsonAddress(json, string.concat(basePath, ".collateralToken"))
            });
            
            console.log("Loaded token: %s (%s)", tokens[i].symbol, vm.toString(tokens[i].tokenAddress));
        }
        
        return tokens;
    }
    
    /**
     * @notice Create mock token data for testing
     * @return tokens Array of mock token data
     */
    function createMockTokenData() internal returns (LiquidityCalculationEngine.TokenData[] memory) {
        LiquidityCalculationEngine.TokenData[] memory tokens = new LiquidityCalculationEngine.TokenData[](4);
        
        // Mock GNO token
        address gnoCollateral = 0x9C58BAcC331c9aa871AFD802DB6379a98e80CEdb;
        
        // Mock sDAI token
        address sdaiCollateral = 0xaf204776c7245bF4147c2612BF6e5972Ee483701;
        
        // Create mock YES/NO tokens for GNO
        tokens[0] = LiquidityCalculationEngine.TokenData({
            tokenAddress: address(uint160(uint256(keccak256("YES_GNO")))),
            tokenType: "token1Yes",
            symbol: "YES_GNO",
            decimals: 18,
            collateralToken: gnoCollateral
        });
        
        tokens[1] = LiquidityCalculationEngine.TokenData({
            tokenAddress: address(uint160(uint256(keccak256("NO_GNO")))),
            tokenType: "token1No",
            symbol: "NO_GNO",
            decimals: 18,
            collateralToken: gnoCollateral
        });
        
        // Create mock YES/NO tokens for sDAI
        tokens[2] = LiquidityCalculationEngine.TokenData({
            tokenAddress: address(uint160(uint256(keccak256("YES_sDAI")))),
            tokenType: "token2Yes",
            symbol: "YES_sDAI",
            decimals: 18,
            collateralToken: sdaiCollateral
        });
        
        tokens[3] = LiquidityCalculationEngine.TokenData({
            tokenAddress: address(uint160(uint256(keccak256("NO_sDAI")))),
            tokenType: "token2No",
            symbol: "NO_sDAI",
            decimals: 18,
            collateralToken: sdaiCollateral
        });
        
        for (uint256 i = 0; i < tokens.length; i++) {
            console.log("Created mock token: %s (%s)", tokens[i].symbol, vm.toString(tokens[i].tokenAddress));
        }
        
        return tokens;
    }
    
    /**
     * @notice Validate the liquidity calculation results
     * @param pools Array of pool liquidity data
     */
    function validateResults(LiquidityCalculationEngine.PoolLiquidity[] memory pools) internal {
        console.log("Validating results...");
        
        // Check if we have enough pools
        require(pools.length == 8, "Expected 8 pools (4 v2 token-WXDAI, 2 v2 YES/YES/NO/NO, 2 v3)");
        
        // Check v2 pools
        for (uint256 i = 0; i < 6; i++) {
            require(!pools[i].isV3, "First 6 pools should be v2 pools");
        }
        
        // Check v3 pools
        for (uint256 i = 6; i < 8; i++) {
            require(pools[i].isV3, "Last 2 pools should be v3 pools");
            require(pools[i].fee == 1000, "v3 pools should have 0.1% fee");
            require(pools[i].tickLower < pools[i].tickUpper, "Tick upper must be greater than tick lower");
        }
        
        console.log("Results validation successful!");
    }
}
