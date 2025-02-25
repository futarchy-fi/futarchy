// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "./SushiswapPriceOracle.sol";

/**
 * @title PriceOracleService
 * @notice Service for fetching and processing token prices
 * @dev Uses SushiswapPriceOracle to fetch prices from the Sushiswap API
 */
contract PriceOracleService is Script {
    using SushiswapPriceOracle for *;

    struct ProposalPriceData {
        SushiswapPriceOracle.TokenPriceData token1;
        SushiswapPriceOracle.TokenPriceData token2;
        uint256 token1YesPrice;
        uint256 token1NoPrice;
        uint256 token2YesPrice;
        uint256 token2NoPrice;
    }

    /**
     * @notice Fetches price data for proposal tokens
     * @param chainId The chain ID
     * @param token1 The first collateral token address
     * @param token2 The second collateral token address
     * @param wxdai The WXDAI token address
     * @return priceData The complete price data for the proposal tokens
     */
    function fetchProposalPriceData(
        uint256 chainId,
        address token1,
        address token2,
        address wxdai
    ) public returns (ProposalPriceData memory priceData) {
        console.log("Fetching price data for tokens");
        console.log("Chain ID: %s", chainId);
        console.log("Token1: %s", vm.toString(token1));
        console.log("Token2: %s", vm.toString(token2));
        console.log("WXDAI: %s", vm.toString(wxdai));
        
        // Fetch token1 price data
        console.log("Fetching Token1 price data...");
        priceData.token1 = SushiswapPriceOracle.fetchTokenPriceData(vm, chainId, token1, wxdai);
        
        // Fetch token2 price data
        console.log("Fetching Token2 price data...");
        priceData.token2 = SushiswapPriceOracle.fetchTokenPriceData(vm, chainId, token2, wxdai);
        
        // Calculate YES/NO token prices
        (priceData.token1YesPrice, priceData.token1NoPrice) = 
            SushiswapPriceOracle.calculateConditionalTokenPrices(priceData.token1.wxdaiPrice);
            
        (priceData.token2YesPrice, priceData.token2NoPrice) = 
            SushiswapPriceOracle.calculateConditionalTokenPrices(priceData.token2.wxdaiPrice);
        
        // Log the fetched prices
        logPriceData(priceData);
        
        return priceData;
    }
    
    /**
     * @notice Logs the fetched price data
     * @param priceData The price data to log
     */
    function logPriceData(ProposalPriceData memory priceData) internal view {
        console.log("=== Fetched Price Data ===");
        console.log("Token1 (%s):", priceData.token1.symbol);
        console.log("  USD Price: %s USD", formatPrice(priceData.token1.usdPrice));
        console.log("  WXDAI Price: %s WXDAI", formatPrice(priceData.token1.wxdaiPrice));
        console.log("  YES Token Initial Price: %s WXDAI", formatPrice(priceData.token1YesPrice));
        console.log("  NO Token Initial Price: %s WXDAI", formatPrice(priceData.token1NoPrice));
        
        console.log("Token2 (%s):", priceData.token2.symbol);
        console.log("  USD Price: %s USD", formatPrice(priceData.token2.usdPrice));
        console.log("  WXDAI Price: %s WXDAI", formatPrice(priceData.token2.wxdaiPrice));
        console.log("  YES Token Initial Price: %s WXDAI", formatPrice(priceData.token2YesPrice));
        console.log("  NO Token Initial Price: %s WXDAI", formatPrice(priceData.token2NoPrice));
    }
    
    /**
     * @notice Helper function to format price with proper decimals
     * @param price The price with 18 decimals
     * @return formattedPrice The formatted price string
     */
    function formatPrice(uint256 price) internal pure returns (string memory) {
        // Convert price from 18 decimals to a readable string format
        uint256 integerPart = price / 1e18;
        uint256 decimalPart = price % 1e18;
        
        // Format decimalPart to 6 decimal places
        uint256 sixDecimals = (decimalPart * 1000000) / 1e18;
        
        return string.concat(
            vm.toString(integerPart),
            ".",
            formatDecimals(sixDecimals, 6)
        );
    }
    
    /**
     * @notice Helper function to format decimal places with leading zeros
     * @param value The decimal value
     * @param places The number of decimal places
     * @return formatted The formatted decimal string
     */
    function formatDecimals(uint256 value, uint256 places) internal pure returns (string memory) {
        string memory result = vm.toString(value);
        uint256 length = bytes(result).length;
        
        if (length >= places) {
            return result;
        }
        
        // Add leading zeros
        string memory zeros = "";
        for (uint256 i = 0; i < places - length; i++) {
            zeros = string.concat(zeros, "0");
        }
        
        return string.concat(zeros, result);
    }
} 