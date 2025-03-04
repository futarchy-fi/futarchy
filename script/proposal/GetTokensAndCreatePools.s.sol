// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {IERC20} from "../../src/interfaces/IERC20Extended.sol";
import {IERC20Extended} from "../../src/interfaces/IERC20Extended.sol";
import {IFutarchyProposal} from "../../src/interfaces/IFutarchyProposal.sol";
import {IFutarchyRouter} from "../../src/interfaces/IFutarchyRouter.sol";
import {LiquidityCalculationEngine} from "../../src/liquidity/LiquidityCalculationEngine.sol";

// Interface for SushiSwap router
interface ISushiSwapRouter {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
}

// Interface for SushiSwap factory
interface ISushiSwapFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

// Interface for WXDAI token with deposit function
interface IWXDAI is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

/**
 * @title GetTokensAndCreatePools
 * @notice Script to get conditional tokens using FutarchyRouter and create pools with SushiSwap directly
 */
contract GetTokensAndCreatePools is Script {
    // Configuration
    struct Config {
        address proposalAddress;     // The proposal address 
        address futarchyRouter;      // FutarchyRouter address
        address sushiV2Factory;      // SushiSwap V2 factory
        address sushiV2Router;       // SushiSwap V2 router
        address wxdai;               // WXDAI token
        uint256 wxdaiAmount;         // Amount of WXDAI for liquidity
        uint256 privateKey;          // Private key
        address sender;              // Sender address derived from private key
    }

    // Pool information
    struct PoolInfo {
        address token0;
        address token1;
        uint256 amount0;
        uint256 amount1;
        address pairAddress;         // Address of the created pool (SLP token)
    }

    // Main script variables
    Config public config;
    address[] public conditionalTokens;
    address[] public createdPoolAddresses;

    // Events
    event LiquidityAdded(address indexed pair, uint256 amount0, uint256 amount1, uint256 liquidity);

    /**
     * @notice Loads configuration from environment variables
     */
    function loadConfig() internal returns (Config memory) {
        Config memory cfg;
        
        // Required environment variables
        cfg.proposalAddress = vm.envAddress("PROPOSAL_ADDRESS");
        cfg.futarchyRouter = vm.envAddress("FUTARCHY_ROUTER");
        cfg.sushiV2Factory = vm.envAddress("SUSHI_V2_FACTORY");
        cfg.sushiV2Router = vm.envAddress("SUSHI_V2_ROUTER");
        cfg.wxdai = vm.envAddress("WXDAI_ADDRESS");
        cfg.wxdaiAmount = vm.envUint("WXDAI_AMOUNT");
        cfg.privateKey = vm.envUint("PRIVATE_KEY");
        
        // Derive sender address from private key
        cfg.sender = vm.addr(cfg.privateKey);
        
        return cfg;
    }

    /**
     * @notice Ensures we have enough WXDAI by wrapping native DAI if needed
     * @param requiredAmount The amount of WXDAI needed
     * @return The amount of WXDAI available for use
     */
    function ensureWXDAI(uint256 requiredAmount) internal returns (uint256) {
        IWXDAI wxdai = IWXDAI(config.wxdai);
        
        // Check current WXDAI balance of sender, not script contract
        uint256 wxdaiBalance = wxdai.balanceOf(config.sender);
        console.log("Current WXDAI balance of %s: %s", vm.toString(config.sender), vm.toString(wxdaiBalance));
        
        // Check native DAI balance
        uint256 nativeBalance = config.sender.balance;
        console.log("Current native DAI balance: %s", vm.toString(nativeBalance));
        
        if (wxdaiBalance >= requiredAmount) {
            console.log("Sufficient WXDAI balance available");
            return requiredAmount;
        }
        
        // Calculate how much more WXDAI we need
        uint256 additionalWXDAINeeded = requiredAmount - wxdaiBalance;
        
        // Since we're using the sender's balance, we can't directly wrap here
        // The user needs to manually wrap DAI to WXDAI before running this script
        console.log("Warning: Insufficient WXDAI. Please wrap more DAI to WXDAI before running this script.");
        console.log("Will proceed with available balance: %s WXDAI", vm.toString(wxdaiBalance));
        
        return wxdaiBalance;
    }

    /**
     * @notice Gets conditional tokens using FutarchyRouter
     * @param proposalAddress The address of the proposal
     * @param wxdaiAmount The amount of WXDAI to split
     * @return tokens Array of conditional token addresses
     */
    function getConditionalTokens(address proposalAddress, uint256 wxdaiAmount) internal returns (address[] memory) {
        // Access the proposal
        IFutarchyProposal proposal = IFutarchyProposal(proposalAddress);
        
        // Get collateral token (WXDAI)
        IERC20 collateral1 = proposal.collateralToken1();
        
        console.log("Collateral token 1: %s", vm.toString(address(collateral1)));
        
        // Access the router
        IFutarchyRouter router = IFutarchyRouter(config.futarchyRouter);
        
        // Check the number of outcomes
        uint256 numOutcomes = proposal.numOutcomes();
        console.log("Number of outcomes: %s", vm.toString(numOutcomes));
        
        // Extract tokens for each outcome
        address[] memory tokens = new address[](numOutcomes);
        for (uint256 i = 0; i < numOutcomes; i++) {
            (IERC20 wrapped1155, ) = proposal.wrappedOutcome(i);
            tokens[i] = address(wrapped1155);
            console.log("Outcome %d token: %s", i, vm.toString(address(wrapped1155)));
        }
        
        // Ensure we have enough WXDAI
        wxdaiAmount = ensureWXDAI(wxdaiAmount);
        
        if (wxdaiAmount == 0) {
            console.log("Error: No WXDAI available for splitting position");
            return tokens;
        }
        
        // Approve WXDAI for router
        IERC20 wxdai = IERC20(config.wxdai);
        wxdai.approve(config.futarchyRouter, wxdaiAmount);
        console.log("Approved WXDAI for router: %s", vm.toString(wxdaiAmount));
        
        // Split position using router
        console.log("Splitting position with amount: %s", vm.toString(wxdaiAmount));
        router.splitPosition(proposal, IERC20(collateral1), wxdaiAmount);
        
        // Log balances after split
        for (uint256 i = 0; i < numOutcomes; i++) {
            uint256 tokenBalance = IERC20(tokens[i]).balanceOf(config.sender);
            console.log("Outcome %d token balance after split: %s", i, vm.toString(tokenBalance));
        }
        
        return tokens;
    }

    /**
     * @notice Prepares pool configurations
     * @param tokens Array of conditional token addresses
     * @param wxdaiAmount Amount of WXDAI to use for each pool
     * @return pools Array of pool configurations
     */
    function preparePoolConfigs(address[] memory tokens, uint256 wxdaiAmount) internal returns (PoolInfo[] memory) {
        // Check for minimum token balances first
        uint256 numTokensWithBalance = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 tokenBalance = IERC20(tokens[i]).balanceOf(config.sender);
            if (tokenBalance > 0) {
                numTokensWithBalance++;
            }
        }
        
        if (numTokensWithBalance == 0) {
            console.log("No outcome tokens with balance available. Cannot create pools.");
            return new PoolInfo[](0);
        }
        
        // We'll only create pools for tokens with balances
        PoolInfo[] memory pools = new PoolInfo[](numTokensWithBalance);
        uint256 wxdaiPerPool = wxdaiAmount / numTokensWithBalance;
        
        console.log("Preparing %d pool configurations with %s WXDAI per pool", 
            numTokensWithBalance, vm.toString(wxdaiPerPool));
        
        uint256 poolIndex = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            // Get token balance from sender, not script contract
            uint256 tokenBalance = IERC20(tokens[i]).balanceOf(config.sender);
            console.log("Token %d balance: %s", i, vm.toString(tokenBalance));
            
            if (tokenBalance > 0) {
                pools[poolIndex] = PoolInfo({
                    token0: config.wxdai,
                    token1: tokens[i],
                    amount0: wxdaiPerPool,
                    amount1: tokenBalance,
                    pairAddress: address(0)  // Will be set after pool creation
                });
                
                console.log("Pool %d configuration:", poolIndex);
                console.log("  token0 (WXDAI): %s", vm.toString(pools[poolIndex].token0));
                console.log("  token1 (Outcome): %s", vm.toString(pools[poolIndex].token1));
                console.log("  amount0: %s", vm.toString(pools[poolIndex].amount0));
                console.log("  amount1: %s", vm.toString(pools[poolIndex].amount1));
                
                poolIndex++;
            }
        }
        
        return pools;
    }

    /**
     * @notice Creates pools by directly interacting with SushiSwap router
     * @param pools Array of pool configurations
     * @return updatedPools Array of pool configurations with pair addresses
     */
    function createPools(PoolInfo[] memory pools) internal returns (PoolInfo[] memory) {
        if (pools.length == 0) {
            console.log("No pools to create - skipping pool creation");
            return pools;
        }
        
        // Get references to SushiSwap contracts
        ISushiSwapFactory factory = ISushiSwapFactory(config.sushiV2Factory);
        ISushiSwapRouter router = ISushiSwapRouter(config.sushiV2Router);
        
        // Deploy pools
        for (uint256 i = 0; i < pools.length; i++) {
            console.log("Creating pool %d", i);
            
            // Create pair if it doesn't exist
            address pair = factory.getPair(pools[i].token0, pools[i].token1);
            if (pair == address(0)) {
                console.log("Creating new pair between %s and %s", 
                    vm.toString(pools[i].token0), 
                    vm.toString(pools[i].token1));
                pair = factory.createPair(pools[i].token0, pools[i].token1);
                console.log("Pair created at address: %s", vm.toString(pair));
            } else {
                console.log("Using existing pair at address: %s", vm.toString(pair));
            }
            
            // Store the pair address
            pools[i].pairAddress = pair;
            createdPoolAddresses.push(pair);
            
            // Check token balances before approval
            IERC20 token0 = IERC20(pools[i].token0);
            IERC20 token1 = IERC20(pools[i].token1);
            uint256 token0Balance = token0.balanceOf(config.sender);
            uint256 token1Balance = token1.balanceOf(config.sender);
            console.log("Balance before approval - token0: %s, token1: %s", 
                vm.toString(token0Balance), 
                vm.toString(token1Balance));
                
            // Verify we have enough balance
            if (token0Balance < pools[i].amount0) {
                console.log("ERROR: Not enough token0 balance. Have: %s, Need: %s", 
                    vm.toString(token0Balance), 
                    vm.toString(pools[i].amount0));
                continue;
            }
            if (token1Balance < pools[i].amount1) {
                console.log("ERROR: Not enough token1 balance. Have: %s, Need: %s", 
                    vm.toString(token1Balance), 
                    vm.toString(pools[i].amount1));
                continue;
            }
            
            // Check current allowances
            uint256 token0Allowance = token0.allowance(config.sender, config.sushiV2Router);
            uint256 token1Allowance = token1.allowance(config.sender, config.sushiV2Router);
            console.log("Allowance before approval - token0: %s, token1: %s", 
                vm.toString(token0Allowance), 
                vm.toString(token1Allowance));
            
            // Approve router to spend our tokens
            token0.approve(config.sushiV2Router, pools[i].amount0);
            token1.approve(config.sushiV2Router, pools[i].amount1);
            console.log("Approved SushiSwap router to spend our tokens");
            
            // Verify approvals went through
            token0Allowance = token0.allowance(config.sender, config.sushiV2Router);
            token1Allowance = token1.allowance(config.sender, config.sushiV2Router);
            console.log("Allowance after approval - token0: %s, token1: %s", 
                vm.toString(token0Allowance), 
                vm.toString(token1Allowance));
            
            // Calculate min amounts (1% slippage tolerance)
            uint256 amountAMin = pools[i].amount0 * 99 / 100;
            uint256 amountBMin = pools[i].amount1 * 99 / 100;
            
            console.log("Adding liquidity with parameters:");
            console.log("  token0: %s", vm.toString(pools[i].token0));
            console.log("  token1: %s", vm.toString(pools[i].token1));
            console.log("  amount0Desired: %s", vm.toString(pools[i].amount0));
            console.log("  amount1Desired: %s", vm.toString(pools[i].amount1));
            console.log("  amount0Min: %s", vm.toString(amountAMin));
            console.log("  amount1Min: %s", vm.toString(amountBMin));
            console.log("  to: %s", vm.toString(config.sender));
            console.log("  deadline: %s", vm.toString(block.timestamp + 1800));
            
            // Add liquidity directly from our account
            try router.addLiquidity(
                pools[i].token0,
                pools[i].token1,
                pools[i].amount0,
                pools[i].amount1,
                amountAMin,
                amountBMin,
                config.sender,  // LP tokens go to sender
                block.timestamp + 1800  // 30 minute deadline
            ) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
                console.log("Pool %d created successfully:", i);
                console.log("  Actual amount0: %s", vm.toString(amountA));
                console.log("  Actual amount1: %s", vm.toString(amountB));
                console.log("  Liquidity: %s", vm.toString(liquidity));
                
                // Emit event
                emit LiquidityAdded(pair, amountA, amountB, liquidity);
            } catch Error(string memory reason) {
                console.log("Failed to create pool %d: %s", i, reason);
                
                // Check balances again to see if they changed
                token0Balance = token0.balanceOf(config.sender);
                token1Balance = token1.balanceOf(config.sender);
                console.log("Balance after failure - token0: %s, token1: %s", 
                    vm.toString(token0Balance), 
                    vm.toString(token1Balance));
                    
                // Check allowances again
                token0Allowance = token0.allowance(config.sender, config.sushiV2Router);
                token1Allowance = token1.allowance(config.sender, config.sushiV2Router);
                console.log("Allowance after failure - token0: %s, token1: %s", 
                    vm.toString(token0Allowance), 
                    vm.toString(token1Allowance));
            } catch {
                console.log("Failed to create pool %d (unknown error)", i);
            }
        }
        
        return pools;
    }

    /**
     * @notice Generates verification commands for the created pools
     * @param pools Array of pool information
     */
    function generateVerificationScript(PoolInfo[] memory pools) internal {
        if (pools.length == 0 || createdPoolAddresses.length == 0) {
            console.log("No pools to verify");
            return;
        }
        
        // Get Etherscan API key from environment
        string memory etherscanApiKey = vm.envString("ETHERSCAN_API_KEY");
        
        console.log("\n==== Contract Verification Commands ====");
        console.log("Run the following commands to verify the created SushiSwap V2 Pairs:");
        
        // Only generate verification commands for pool pairs
        for (uint256 i = 0; i < pools.length; i++) {
            if (pools[i].pairAddress != address(0)) {
                string memory pairVerifyCmd = string.concat(
                    "forge verify-contract ",
                    vm.toString(pools[i].pairAddress),
                    " @sushiswap/v2-core/contracts/UniswapV2Pair.sol:UniswapV2Pair",
                    " --chain-id 100",
                    " --etherscan-api-key ",
                    etherscanApiKey
                );
                console.log("%s", pairVerifyCmd);
            }
        }
        
        console.log("\nVerification commands are ready to run");
        console.log("======================================");
    }

    /**
     * @notice Main entry point
     * @param proposalAddress The address of the proposal
     */
    function run(address proposalAddress) external {
        // Load configuration
        config = loadConfig();
        
        // Override proposal address if provided
        if (proposalAddress != address(0)) {
            config.proposalAddress = proposalAddress;
        }
        
        console.log("Starting GetTokensAndCreatePools script");
        console.log("Proposal address: %s", vm.toString(config.proposalAddress));
        console.log("FutarchyRouter: %s", vm.toString(config.futarchyRouter));
        console.log("SushiSwap V2 Factory: %s", vm.toString(config.sushiV2Factory));
        console.log("SushiSwap V2 Router: %s", vm.toString(config.sushiV2Router));
        console.log("WXDAI: %s", vm.toString(config.wxdai));
        console.log("WXDAI amount: %s", vm.toString(config.wxdaiAmount));
        console.log("Sender address: %s", vm.toString(config.sender));
        
        // Start broadcasting transactions
        vm.startBroadcast(config.privateKey);
        
        // Get conditional tokens
        address[] memory tokens = getConditionalTokens(config.proposalAddress, config.wxdaiAmount);
        
        // Prepare pool configurations
        PoolInfo[] memory pools = preparePoolConfigs(tokens, config.wxdaiAmount);
        
        // Create pools
        pools = createPools(pools);
        
        // Stop broadcasting
        vm.stopBroadcast();
        
        // Generate verification script for the created contracts
        generateVerificationScript(pools);
        
        console.log("GetTokensAndCreatePools script completed");
    }
} 