// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../../src/interfaces/IFutarchyProposal.sol";
import "../../src/interfaces/ISushiswapV2Factory.sol";
import "../../src/interfaces/ISushiswapV2Router.sol";

/**
 * @title DeployConditionalPools
 * @notice Script to deploy SushiSwap V2 pools for futarchy conditional tokens
 * @dev Creates v2 pools for token1yes/token2yes and token1no/token2no pairs
 */
contract DeployConditionalPools is Script {
    // Contract interfaces
    ISushiswapV2Factory public factory;
    ISushiswapV2Router public router;
    IFutarchyProposal public proposal;

    // Token addresses
    address public token1Yes;
    address public token2Yes;
    address public token1No;
    address public token2No;
    
    // Pool configuration
    uint256 public amount0;
    uint256 public amount1;
    
    struct TokenData {
        address address_;
        string symbol;
        uint8 decimals;
        string tokenType;
    }
    
    function setUp() public {
        // Load contract addresses from environment
        factory = ISushiswapV2Factory(vm.envAddress("SUSHI_V2_FACTORY"));
        router = ISushiswapV2Router(vm.envAddress("SUSHI_V2_ROUTER"));
        
        // Load proposal address
        address proposalAddress = vm.envAddress("PROPOSAL_ADDRESS");
        proposal = IFutarchyProposal(proposalAddress);
        
        // Load liquidity amounts from environment variables
        amount0 = vm.envUint("AMOUNT0");
        amount1 = vm.envUint("AMOUNT1");
        
        console.log("Pool Configuration:");
        console.log("- Amount0:", amount0);
        console.log("- Amount1:", amount1);
        
        // Extract token addresses from the proposal
        extractConditionalTokens();
    }
    
    function extractConditionalTokens() internal {
        // Query the proposal for outcome tokens
        token1Yes = proposal.wrappedOutcome(0); // token1Yes is usually at index 0
        token1No = proposal.wrappedOutcome(1);  // token1No is usually at index 1
        token2Yes = proposal.wrappedOutcome(2); // token2Yes is usually at index 2
        token2No = proposal.wrappedOutcome(3);  // token2No is usually at index 3
        
        console.log("Extracted tokens from proposal:");
        console.log("token1Yes:", token1Yes);
        console.log("token1No:", token1No);
        console.log("token2Yes:", token2Yes);
        console.log("token2No:", token2No);
    }

    function run() public {
        vm.startBroadcast();
        
        // Step 1: Create SushiSwap V2 pools for token1yes/token2yes (YES/YES pool)
        address yesPool = createV2Pool(token1Yes, token2Yes);
        console.log("YES/YES Pool deployed at:", yesPool);
        
        // Step 2: Create SushiSwap V2 pools for token1no/token2no (NO/NO pool)
        address noPool = createV2Pool(token1No, token2No);
        console.log("NO/NO Pool deployed at:", noPool);
        
        // Step 3: Add liquidity to the pools
        addLiquidityToPool(token1Yes, token2Yes, amount0, amount1);
        addLiquidityToPool(token1No, token2No, amount0, amount1);
        
        vm.stopBroadcast();
    }
    
    function createV2Pool(address tokenA, address tokenB) internal returns (address pool) {
        // Check if pool already exists
        pool = factory.getPair(tokenA, tokenB);
        if (pool != address(0)) {
            console.log("Pool already exists at:", pool);
            return pool;
        }
        
        // Create new pool using SushiSwap V2 Factory
        pool = factory.createPair(tokenA, tokenB);
        console.log("Created new pool at:", pool);
        return pool;
    }
    
    function addLiquidityToPool(
        address tokenA, 
        address tokenB, 
        uint256 amountA,
        uint256 amountB
    ) internal {
        // Approve tokens to router
        IERC20(tokenA).approve(address(router), amountA);
        IERC20(tokenB).approve(address(router), amountB);
        
        // Add liquidity using SushiSwap V2 Router
        (uint256 amountAUsed, uint256 amountBUsed, uint256 liquidity) = router.addLiquidity(
            tokenA,
            tokenB,
            amountA,
            amountB,
            0,  // Min amount A (accept any slippage for this deployment)
            0,  // Min amount B (accept any slippage for this deployment)
            address(this),
            block.timestamp + 600  // 10 minutes deadline
        );
        
        console.log("Liquidity added to pool:");
        console.log("- Amount A used:", amountAUsed);
        console.log("- Amount B used:", amountBUsed);
        console.log("- Liquidity tokens received:", liquidity);
    }
} 