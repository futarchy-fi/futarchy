// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../interfaces/ISushiswapV3Factory.sol";
import "../interfaces/ISushiswapV3PositionManager.sol";
import "../interfaces/ISushiswapV3Pool.sol";
import "../interfaces/IERC20Extended.sol";
import "./LiquidityCalculationEngine.sol";

/**
 * @title V3PoolDeploymentEngine
 * @notice Handles the deployment of SushiSwap V3 pools with concentrated liquidity
 * @dev Integrates with LiquidityCalculationEngine outputs to create v3 pools with proper price ranges
 */
contract V3PoolDeploymentEngine is Script {
    /// @notice The SushiSwap V3 factory contract
    ISushiswapV3Factory public immutable sushiV3Factory;
    
    /// @notice The SushiSwap V3 position manager contract
    ISushiswapV3PositionManager public immutable sushiV3PositionManager;

    /// @notice Event emitted when a v3 pool is created
    event V3PoolCreated(address token0, address token1, uint24 fee, address pool);
    
    /// @notice Event emitted when a v3 position is created
    event V3PositionCreated(address pool, uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    /**
     * @notice Constructor to initialize with contract addresses
     * @param _factory SushiSwap V3 factory address
     * @param _positionManager SushiSwap V3 position manager address
     */
    constructor(address _factory, address _positionManager) {
        sushiV3Factory = ISushiswapV3Factory(_factory);
        sushiV3PositionManager = ISushiswapV3PositionManager(_positionManager);
    }

    /**
     * @notice Checks if a v3 pool exists
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param fee Fee tier
     * @return pool The pool address (zero address if not exists)
     */
    function poolExists(address tokenA, address tokenB, uint24 fee) public view returns (address pool) {
        return sushiV3Factory.getPool(tokenA, tokenB, fee);
    }

    /**
     * @notice Converts price to sqrtPriceX96 format required by SushiSwap V3
     * @param price The price with 18 decimals precision
     * @return sqrtPriceX96 The square root of price in Q64.96 format
     */
    function calculateSqrtPriceX96(uint256 price) public pure returns (uint160 sqrtPriceX96) {
        // Calculate sqrt(price) with 1e18 precision
        uint256 sqrtPrice = sqrt(price * 1e18);
        
        // Convert to Q64.96 format
        sqrtPriceX96 = uint160((sqrtPrice * (2**96)) / 1e18);
        
        return sqrtPriceX96;
    }
    
    /**
     * @notice Square root calculation using Newton's method
     * @param x The number to calculate the square root of
     * @return y The square root with 1e18 precision
     */
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        
        // Adjust precision to 1e18
        return y * 1e9; // Assuming x has 1e18 precision, sqrt(x) has 1e9 precision, so we multiply by 1e9
    }

    /**
     * @notice Ensures token spending is approved for the position manager
     * @param token Token to approve
     * @param amount Amount to approve
     */
    function ensureTokenApproval(address token, uint256 amount) public {
        IERC20 tokenContract = IERC20(token);
        uint256 allowance = tokenContract.allowance(address(this), address(sushiV3PositionManager));
        
        if (allowance < amount) {
            console2.log("Approving SushiSwap V3 Position Manager to spend token:", token);
            console2.log("Amount:", amount);
            tokenContract.approve(address(sushiV3PositionManager), type(uint256).max);
        }
    }

    /**
     * @notice Creates a V3 pool and initializes it with a specific price
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param fee Fee tier
     * @param sqrtPriceX96 Initial price in sqrtPriceX96 format
     * @return pool The pool address
     */
    function createAndInitializePool(
        address tokenA,
        address tokenB,
        uint24 fee,
        uint160 sqrtPriceX96
    ) public returns (address pool) {
        // Check if pool already exists
        pool = poolExists(tokenA, tokenB, fee);
        
        if (pool == address(0)) {
            console2.log("Creating and initializing new V3 pool:");
            console2.log("  Token0:", tokenA);
            console2.log("  Token1:", tokenB);
            console2.log("  Fee tier:", fee);
            console2.log("  Initial sqrtPriceX96:", uint256(sqrtPriceX96));
            
            // Create and initialize the pool
            pool = sushiV3PositionManager.createAndInitializePoolIfNecessary(
                tokenA,
                tokenB,
                fee,
                sqrtPriceX96
            );
            
            emit V3PoolCreated(tokenA, tokenB, fee, pool);
            console2.log("Pool created at address:", pool);
        } else {
            console2.log("Pool already exists at address:", pool);
        }
        
        return pool;
    }

    /**
     * @notice Adds a concentrated liquidity position to a V3 pool
     * @param pool Pool liquidity parameters
     * @param poolAddress Address of the V3 pool
     * @return tokenId The ID of the NFT representing the position
     * @return liquidity The amount of liquidity in the position
     * @return amount0 The amount of token0 actually used
     * @return amount1 The amount of token1 actually used
     */
    function addInitialPosition(
        LiquidityCalculationEngine.PoolLiquidity memory pool,
        address poolAddress
    ) public returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) {
        // Ensure token approvals
        ensureTokenApproval(pool.token0, pool.amount0);
        ensureTokenApproval(pool.token1, pool.amount1);
        
        // Calculate min amounts (1% slippage tolerance)
        uint256 amount0Min = pool.amount0 * 99 / 100;
        uint256 amount1Min = pool.amount1 * 99 / 100;
        
        console2.log("Adding concentrated liquidity position:");
        console2.log("  Pool address:", poolAddress);
        console2.log("  Token0:", pool.token0);
        console2.log("  Token1:", pool.token1);
        console2.log("  Amount0:", pool.amount0);
        console2.log("  Amount1:", pool.amount1);
        console2.log("  Tick lower:", pool.tickLower);
        console2.log("  Tick upper:", pool.tickUpper);
        
        // Create parameters for position creation
        ISushiswapV3PositionManager.MintParams memory params = ISushiswapV3PositionManager.MintParams({
            token0: pool.token0,
            token1: pool.token1,
            fee: pool.fee,
            tickLower: pool.tickLower,
            tickUpper: pool.tickUpper,
            amount0Desired: pool.amount0,
            amount1Desired: pool.amount1,
            amount0Min: amount0Min,
            amount1Min: amount1Min,
            recipient: address(this),
            deadline: block.timestamp + 1800  // 30 minute deadline
        });
        
        // Create the position
        (tokenId, liquidity, amount0, amount1) = sushiV3PositionManager.mint(params);
        
        emit V3PositionCreated(poolAddress, tokenId, liquidity, amount0, amount1);
        
        console2.log("Position created successfully:");
        console2.log("  NFT token ID:", tokenId);
        console2.log("  Liquidity:", uint256(liquidity));
        console2.log("  Actual amount0:", amount0);
        console2.log("  Actual amount1:", amount1);
        
        return (tokenId, liquidity, amount0, amount1);
    }

    /**
     * @notice Deploys a V3 pool and adds concentrated liquidity in one transaction
     * @param pool The pool liquidity parameters
     * @return poolAddress The pool address
     * @return tokenId The ID of the NFT representing the position
     * @return liquidity The amount of liquidity in the position
     */
    function deployPool(
        LiquidityCalculationEngine.PoolLiquidity memory pool
    ) public returns (address poolAddress, uint256 tokenId, uint128 liquidity) {
        // Skip if this is not a V3 pool configuration
        if (!pool.isV3) {
            console2.log("Skipping V2 pool deployment (not handled by this engine)");
            return (address(0), 0, 0);
        }
        
        // Calculate sqrtPriceX96 from initialPrice
        uint160 sqrtPriceX96 = calculateSqrtPriceX96(pool.initialPrice);
        
        // Create and initialize the pool
        poolAddress = createAndInitializePool(
            pool.token0,
            pool.token1,
            pool.fee,
            sqrtPriceX96
        );
        
        // Add the initial concentrated liquidity position
        (tokenId, liquidity,,) = addInitialPosition(pool, poolAddress);
        
        return (poolAddress, tokenId, liquidity);
    }

    /**
     * @notice Deploys multiple V3 pools from the provided pool liquidity parameters
     * @param pools Array of pool liquidity parameters
     * @return poolAddresses Array of deployed pool addresses
     * @return tokenIds Array of NFT token IDs for the positions
     */
    function deployV3Pools(
        LiquidityCalculationEngine.PoolLiquidity[] memory pools
    ) public returns (address[] memory poolAddresses, uint256[] memory tokenIds) {
        console2.log("Deploying V3 pools with concentrated liquidity...");
        
        // Count the number of V3 pools
        uint256 v3PoolCount = 0;
        for (uint256 i = 0; i < pools.length; i++) {
            if (pools[i].isV3) {
                v3PoolCount++;
            }
        }
        
        // Initialize arrays for results
        poolAddresses = new address[](v3PoolCount);
        tokenIds = new uint256[](v3PoolCount);
        
        // Deploy each V3 pool
        uint256 poolIndex = 0;
        for (uint256 i = 0; i < pools.length; i++) {
            if (pools[i].isV3) {
                try this.deployPool(pools[i]) returns (address poolAddress, uint256 tokenId, uint128 liquidity) {
                    poolAddresses[poolIndex] = poolAddress;
                    tokenIds[poolIndex] = tokenId;
                    console2.log("Successfully deployed V3 pool", poolIndex);
                    console2.log("  Pool address:", poolAddress);
                    console2.log("  Position ID:", tokenId);
                    console2.log("  Liquidity:", uint256(liquidity));
                    poolIndex++;
                } catch Error(string memory reason) {
                    console2.log("Error deploying V3 pool", poolIndex);
                    console2.log("  Reason:", reason);
                } catch {
                    console2.log("Unknown error deploying V3 pool", poolIndex);
                }
            }
        }
        
        return (poolAddresses, tokenIds);
    }
} 