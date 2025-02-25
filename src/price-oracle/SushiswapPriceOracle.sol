// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "../interfaces/IERC20Extended.sol";

// Extended interface to add decimals function
interface IERC20WithDecimals is IERC20Extended {
    function decimals() external view returns (uint8);
}

/**
 * @title SushiswapPriceOracle
 * @notice Library for fetching token prices from Sushiswap API
 * @dev Uses curl to fetch prices from the Sushiswap API endpoint
 */
library SushiswapPriceOracle {
    /**
     * @notice Structure to hold token price data
     * @param usdPrice USD price of the token
     * @param wxdaiPrice Price in WXDAI terms
     * @param decimals Token decimals
     * @param symbol Token symbol
     */
    struct TokenPriceData {
        uint256 usdPrice;    // Price in USD with 18 decimals (1.0 = 1e18)
        uint256 wxdaiPrice;  // Price in WXDAI with 18 decimals
        uint8 decimals;      // Token decimals
        string symbol;       // Token symbol
    }

    /**
     * @notice Parses a decimal string to a uint256 with 18 decimals
     * @param str The decimal string to parse (e.g. "2419.6400626726513")
     * @return The parsed number with 18 decimals precision
     */
    function parseDecimalString(string memory str) internal pure returns (uint256) {
        bytes memory b = bytes(str);
        uint256 result = 0;
        bool foundDecimal = false;
        uint8 decimals = 0;
        
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == '.') {
                foundDecimal = true;
                continue;
            }
            
            // Only parse digits
            if (uint8(b[i]) >= 48 && uint8(b[i]) <= 57) {
                result = result * 10 + (uint8(b[i]) - 48);
                
                // Count decimals after the decimal point
                if (foundDecimal) {
                    decimals++;
                }
            }
        }
        
        // Scale to 18 decimals
        if (decimals < 18) {
            result = result * (10 ** (18 - decimals));
        } else if (decimals > 18) {
            result = result / (10 ** (decimals - 18));
        }
        
        return result;
    }

    /**
     * @notice Fetches USD price for a token from Sushiswap API
     * @param vm The forge VM instance
     * @param chainId The chain ID
     * @param tokenAddress The token address
     * @return price The USD price with 18 decimals (1.0 = 1e18)
     */
    function fetchTokenUsdPrice(
        Vm vm,
        uint256 chainId, 
        address tokenAddress
    ) internal returns (uint256 price) {
        string memory endpoint = string.concat(
            "https://api.sushi.com/price/v1/",
            vm.toString(chainId),
            "/",
            vm.toString(tokenAddress)
        );
        
        string[] memory inputs = new string[](3);
        inputs[0] = "curl";
        inputs[1] = "-s";
        inputs[2] = endpoint;
        
        // Execute the curl command
        bytes memory result = vm.ffi(inputs);
        
        // Parse the result
        string memory resultStr = string(result);
        
        // Check if we received a valid response
        if (bytes(resultStr).length == 0) {
            console.log("Error: Empty response from Sushiswap API");
            revert("Failed to fetch price: Empty response");
        }
        
        // Log the response for debugging
        console.log("SushiSwap API Response: %s", resultStr);
        
        // Parse the decimal string directly
        return parseDecimalString(resultStr);
    }

    /**
     * @notice Fetches token price data including USD price, WXDAI price, and token metadata
     * @param vm The forge VM instance
     * @param chainId The chain ID
     * @param tokenAddress The token address
     * @param wxdaiAddress The WXDAI token address
     * @return data The token price data
     */
    function fetchTokenPriceData(
        Vm vm,
        uint256 chainId, 
        address tokenAddress, 
        address wxdaiAddress
    ) internal returns (TokenPriceData memory data) {
        // Skip price fetching for WXDAI itself
        if (tokenAddress == wxdaiAddress) {
            data.usdPrice = fetchTokenUsdPrice(vm, chainId, wxdaiAddress);
            data.wxdaiPrice = 1e18; // 1:1 ratio
            data.decimals = IERC20WithDecimals(wxdaiAddress).decimals();
            data.symbol = IERC20Extended(wxdaiAddress).symbol();
            return data;
        }
        
        // Fetch the USD prices
        uint256 tokenUsdPrice = fetchTokenUsdPrice(vm, chainId, tokenAddress);
        uint256 wxdaiUsdPrice = fetchTokenUsdPrice(vm, chainId, wxdaiAddress);
        
        // Calculate WXDAI price
        data.usdPrice = tokenUsdPrice;
        data.wxdaiPrice = (tokenUsdPrice * 1e18) / wxdaiUsdPrice;
        data.decimals = IERC20WithDecimals(tokenAddress).decimals();
        data.symbol = IERC20Extended(tokenAddress).symbol();
        
        return data;
    }

    /**
     * @notice Calculates the YES/NO token prices based on the collateral token price
     * @param collateralPriceInWxdai The collateral token price in WXDAI terms
     * @return yesPrice YES token price in WXDAI
     * @return noPrice NO token price in WXDAI
     */
    function calculateConditionalTokenPrices(uint256 collateralPriceInWxdai) 
        internal 
        pure 
        returns (uint256 yesPrice, uint256 noPrice) 
    {
        // By default, YES and NO tokens are initially priced at half the collateral price
        yesPrice = collateralPriceInWxdai / 2;
        noPrice = collateralPriceInWxdai / 2;
        
        return (yesPrice, noPrice);
    }
} 