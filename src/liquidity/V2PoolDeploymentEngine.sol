// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../interfaces/ISushiswapV2Factory.sol";
import "../interfaces/ISushiswapV2Router.sol";
import "../interfaces/IERC20Extended.sol";
import "./LiquidityCalculationEngine.sol";

/**
 * @title V2PoolDeploymentEngine
 * @notice Handles the deployment of SushiSwap V2 pools for WXDAI paired with YES and NO conditional tokens
 * @dev Integrates with LiquidityCalculationEngine outputs to create balanced pools with proper initial prices
 */
contract V2PoolDeploymentEngine is Script {
    /// @notice The SushiSwap V2 factory contract
    ISushiswapV2Factory public immutable sushiV2Factory;
    
    /// @notice The SushiSwap V2 router contract
    ISushiswapV2Router public immutable sushiV2Router;
    
    /// @notice The WXDAI token contract
    address public immutable wxdai;

    /// @notice Event emitted when a pair is created
    event PairCreated(address token0, address token1, address pair);
    
    /// @notice Event emitted when liquidity is added to a pair
    event LiquidityAdded(address pair, uint256 amount0, uint256 amount1, uint256 liquidity);

    /**
     * @notice Constructor to initialize with contract addresses
     * @param _factory SushiSwap V2 factory address
     * @param _router SushiSwap V2 router address
     * @param _wxdai WXDAI token address
     */
    constructor(address _factory, address _router, address _wxdai) {
        sushiV2Factory = ISushiswapV2Factory(_factory);
        sushiV2Router = ISushiswapV2Router(_router);
        wxdai = _wxdai;
    }

    /**
     * @notice Checks if a pair exists between two tokens
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return pair The pair address (zero address if not exists)
     */
    function pairExists(address tokenA, address tokenB) public view returns (address pair) {
        return sushiV2Factory.getPair(tokenA, tokenB);
    }

    /**
     * @notice Creates a new pair if it doesn't exist
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return pair The pair address (either newly created or existing)
     */
    function createPairIfNeeded(address tokenA, address tokenB) public returns (address pair) {
        // Check if pair already exists
        pair = pairExists(tokenA, tokenB);
        
        // If pair doesn't exist, create it
        if (pair == address(0)) {
            console.log("Creating new pair between %s and %s", vm.toString(tokenA), vm.toString(tokenB));
            pair = sushiV2Factory.createPair(tokenA, tokenB);
            emit PairCreated(tokenA, tokenB, pair);
            console.log("Pair created at address: %s", vm.toString(pair));
        } else {
            console.log("Pair already exists at address: %s", vm.toString(pair));
        }
        
        return pair;
    }

    /**
     * @notice Ensures token spending is approved for the router contract
     * @param token Token to approve
     * @param amount Amount to approve
     */
    function ensureTokenApproval(address token, uint256 amount) public {
        IERC20 tokenContract = IERC20(token);
        uint256 allowance = tokenContract.allowance(address(this), address(sushiV2Router));
        
        if (allowance < amount) {
            console.log("Approving SushiSwap V2 Router to spend %s of token %s", vm.toString(amount), vm.toString(token));
            tokenContract.approve(address(sushiV2Router), type(uint256).max);
        }
    }

    /**
     * @notice Adds liquidity to a pool based on the pool liquidity parameters
     * @param pool The pool liquidity parameters
     * @return amountA The amount of token0 actually added as liquidity
     * @return amountB The amount of token1 actually added as liquidity
     * @return liquidity The amount of LP tokens minted
     */
    function addLiquidity(
        LiquidityCalculationEngine.PoolLiquidity memory pool
    ) public returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        // Ensure token approvals
        ensureTokenApproval(pool.token0, pool.amount0);
        ensureTokenApproval(pool.token1, pool.amount1);
        
        // Calculate min amounts (1% slippage tolerance)
        uint256 amountAMin = pool.amount0 * 99 / 100;
        uint256 amountBMin = pool.amount1 * 99 / 100;
        
        console.log("Adding liquidity to pool:");
        console.log("  Token0: %s", vm.toString(pool.token0));
        console.log("  Token1: %s", vm.toString(pool.token1));
        console.log("  Amount0: %s", vm.toString(pool.amount0));
        console.log("  Amount1: %s", vm.toString(pool.amount1));
        
        // Add liquidity using the router
        (amountA, amountB, liquidity) = sushiV2Router.addLiquidity(
            pool.token0,
            pool.token1,
            pool.amount0,
            pool.amount1,
            amountAMin,
            amountBMin,
            address(this),  // LP tokens go to this contract
            block.timestamp + 1800  // 30 minute deadline
        );
        
        // Get pair address
        address pair = sushiV2Factory.getPair(pool.token0, pool.token1);
        
        // Emit event
        emit LiquidityAdded(pair, amountA, amountB, liquidity);
        
        console.log("Liquidity added successfully:");
        console.log("  Actual amount0: %s", vm.toString(amountA));
        console.log("  Actual amount1: %s", vm.toString(amountB));
        console.log("  LP tokens received: %s", vm.toString(liquidity));
        
        return (amountA, amountB, liquidity);
    }

    /**
     * @notice Deploys a pool and adds liquidity in one transaction
     * @param pool The pool liquidity parameters
     * @return pair The pool address
     * @return liquidity The amount of LP tokens minted
     */
    function deployPool(
        LiquidityCalculationEngine.PoolLiquidity memory pool
    ) public returns (address pair, uint256 liquidity) {
        // Skip if this is a V3 pool configuration
        if (pool.isV3) {
            console.log("Skipping V3 pool deployment (not handled by this engine)");
            return (address(0), 0);
        }
        
        // Create pair if needed
        pair = createPairIfNeeded(pool.token0, pool.token1);
        
        // Add liquidity
        (,, liquidity) = addLiquidity(pool);
        
        return (pair, liquidity);
    }

    /**
     * @notice Deploys multiple pools from a JSON file
     * @param jsonPath Path to the JSON file containing pool liquidity parameters
     * @return pairs Array of deployed pool addresses
     */
    function deployPoolsFromJson(string memory jsonPath) public returns (address[] memory pairs) {
        console.log("Deploying pools from JSON file: %s", jsonPath);
        
        // Read the JSON file
        string memory json = vm.readFile(jsonPath);
        
        // Parse the number of pools
        uint256 poolCount = vm.parseJsonUint(json, ".pools.length");
        console.log("Found %d pools in JSON file", poolCount);
        
        // Initialize array for pair addresses
        pairs = new address[](poolCount);
        
        // Deploy each pool
        for (uint256 i = 0; i < poolCount; i++) {
            string memory basePath = string.concat(".pools[", vm.toString(i), "]");
            
            // Parse pool data
            LiquidityCalculationEngine.PoolLiquidity memory pool;
            
            pool.token0 = vm.parseJsonAddress(json, string.concat(basePath, ".token0"));
            pool.token1 = vm.parseJsonAddress(json, string.concat(basePath, ".token1"));
            pool.amount0 = vm.parseJsonUint(json, string.concat(basePath, ".amount0"));
            pool.amount1 = vm.parseJsonUint(json, string.concat(basePath, ".amount1"));
            pool.initialPrice = vm.parseJsonUint(json, string.concat(basePath, ".initialPrice"));
            pool.isV3 = vm.parseJsonBool(json, string.concat(basePath, ".isV3"));
            
            // Only parse V3 specifics if it's a V3 pool
            if (pool.isV3) {
                // Skip V3 pools
                console.log("Skipping V3 pool at index %d", i);
                continue;
            }
            
            // Deploy the pool
            try this.deployPool(pool) returns (address pair, uint256 liquidity) {
                pairs[i] = pair;
                console.log("Successfully deployed pool %d at address %s with %s liquidity", i, vm.toString(pair), vm.toString(liquidity));
            } catch Error(string memory reason) {
                console.log("Error deploying pool %d: %s", i, reason);
            } catch {
                console.log("Unknown error deploying pool %d", i);
            }
        }
        
        return pairs;
    }
} 