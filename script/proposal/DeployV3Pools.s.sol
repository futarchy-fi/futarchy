// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IFutarchyProposal} from "../../src/interfaces/IFutarchyProposal.sol";
import {INonfungiblePositionManager} from "../../src/interfaces/INonfungiblePositionManager.sol";
import {ISushiswapV3Factory} from "../../src/interfaces/ISushiswapV3Factory.sol";
import {IERC20} from "../../src/interfaces/IERC20Extended.sol";

/**
 * @title DeployV3Pools
 * @notice Script to deploy SushiSwap v3 pools for futarchy conditional tokens
 * @dev Creates v3 pools for token1yes/token2yes and token1no/token2no pairs
 *      with 0.1% fee tier and concentrated liquidity
 */
contract DeployV3Pools is Script {
    INonfungiblePositionManager public positionManager;
    IFutarchyProposal public proposal;

    address public token1Yes;
    address public token2Yes;
    address public token1No;
    address public token2No;

    uint24 public feeTier;
    int24 public tickLower;
    int24 public tickUpper;
    uint256 public amount0;
    uint256 public amount1;

    // Initial price (sqrt price in X96 format for equal price: 2^96)
    uint160 public constant SQRT_PRICE_X96 = 79228162514264337593543950336; // 1:1 price ratio

    function setUp() public {
        positionManager = INonfungiblePositionManager(vm.envAddress("NONFUNGIBLE_POSITION_MANAGER"));
        proposal = IFutarchyProposal(vm.envAddress("PROPOSAL_ADDRESS"));

        feeTier = uint24(vm.envUint("FEE_TIER"));
        tickLower = int24(vm.envInt("TICK_LOWER"));
        tickUpper = int24(vm.envInt("TICK_UPPER"));
        amount0 = vm.envUint("AMOUNT0");
        amount1 = vm.envUint("AMOUNT1");

        console.log("Environment configuration loaded:");
        console.logString("- Position Manager: ");
        console.logAddress(address(positionManager));
        console.logString("- Proposal: ");
        console.logAddress(address(proposal));
        console.logString("- Fee Tier: ");
        console.logUint(feeTier);
        console.logString("- Tick Range: ");
        console.logInt(tickLower);
        console.logString(" to ");
        console.logInt(tickUpper);
        console.logString("- Amounts: ");
        console.logUint(amount0);
        console.logString(", ");
        console.logUint(amount1);

        extractConditionalTokens();
    }

    function extractConditionalTokens() internal {
        token1Yes = proposal.wrappedOutcome(0);
        token1No = proposal.wrappedOutcome(1);
        token2Yes = proposal.wrappedOutcome(2);
        token2No = proposal.wrappedOutcome(3);

        console.log("Extracted tokens from proposal:");
        console.logString("- Token1Yes: ");
        console.logAddress(token1Yes);
        console.logString("- Token1No: ");
        console.logAddress(token1No);
        console.logString("- Token2Yes: ");
        console.logAddress(token2Yes);
        console.logString("- Token2No: ");
        console.logAddress(token2No);
    }

    function run() public {
        vm.startBroadcast();

        // Create and add liquidity to YES/YES pool
        console.log("Creating YES/YES pool:");
        createAndAddLiquidity(token1Yes, token2Yes);

        // Create and add liquidity to NO/NO pool
        console.log("Creating NO/NO pool:");
        createAndAddLiquidity(token1No, token2No);

        vm.stopBroadcast();
    }

    function createAndAddLiquidity(address tokenA, address tokenB) internal {
        // Ensure tokenA < tokenB as required by Uniswap/SushiSwap ordering
        address token0 = tokenA < tokenB ? tokenA : tokenB;
        address token1 = tokenA < tokenB ? tokenB : tokenA;

        console.log("Working with token pair:");
        console.logString("- Token0: ");
        console.logAddress(token0);
        console.logString("- Token1: ");
        console.logAddress(token1);

        // Check token balances and allowances before proceeding
        checkBalancesAndAllowances(token0, token1);

        // Step 1: Approve tokens for the position manager
        console.log("Approving tokens...");
        IERC20(token0).approve(address(positionManager), amount0);
        IERC20(token1).approve(address(positionManager), amount1);

        // Check allowances after approval
        checkAllowances(token0, token1);

        // Step 2: Initialize the pool with a specific price if it doesn't exist
        console.log("Initializing pool...");
        try positionManager.createAndInitializePoolIfNecessary(
            token0,
            token1,
            feeTier,
            SQRT_PRICE_X96
        ) returns (address pool) {
            console.logString("Pool initialized at: ");
            console.logAddress(pool);
            
            // Step 3: Add liquidity by minting a position
            console.log("Adding liquidity...");
            INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: feeTier,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0, // No slippage protection for simplicity
                amount1Min: 0, // No slippage protection for simplicity
                recipient: msg.sender,
                deadline: block.timestamp + 600 // 10 minutes
            });

            try positionManager.mint(params) returns (
                uint256 tokenId, 
                uint128 liquidity, 
                uint256 amount0Used, 
                uint256 amount1Used
            ) {
                console.log("Successfully added liquidity:");
                console.logString("- NFT Token ID: ");
                console.logUint(tokenId);
                console.logString("- Liquidity: ");
                console.logUint(uint256(liquidity));
                console.logString("- Token0 used: ");
                console.logUint(amount0Used);
                console.logString("- Token1 used: ");
                console.logUint(amount1Used);
            } catch Error(string memory reason) {
                console.logString("Failed to add liquidity:");
                console.logString("- Reason: ");
                console.logString(reason);
            } catch (bytes memory) {
                console.logString("Failed to add liquidity (unknown error)");
            }
        } catch Error(string memory reason) {
            console.logString("Pool creation failed:");
            console.logString("- Reason: ");
            console.logString(reason);
            
            // Try to check if pool already exists
            address factory = positionManager.factory();
            console.logString("Checking factory for existing pool:");
            console.logString("- Factory: ");
            console.logAddress(factory);
            
            try ISushiswapV3Factory(factory).getPool(token0, token1, feeTier) returns (address existingPool) {
                console.logString("Existing pool found at: ");
                console.logAddress(existingPool);
                if (existingPool == address(0)) {
                    console.logString("Pool does not exist, but creation still failed");
                }
            } catch Error(string memory factoryError) {
                console.logString("Factory check failed:");
                console.logString("- Reason: ");
                console.logString(factoryError);
            } catch (bytes memory) {
                console.logString("Factory check failed (unknown error)");
            }
        } catch (bytes memory) {
            console.logString("Pool creation failed (unknown error)");
            
            // Additional debugging for any possible issues
            console.logString("Debugging information:");
            console.logString("- Token0 code size: ");
            uint256 token0Size;
            assembly {
                token0Size := extcodesize(token0)
            }
            console.logUint(token0Size);
            
            console.logString("- Token1 code size: ");
            uint256 token1Size;
            assembly {
                token1Size := extcodesize(token1)
            }
            console.logUint(token1Size);
            
            console.logString("- Position Manager code size: ");
            uint256 positionManagerSize;
            assembly {
                positionManagerSize := extcodesize(sload(positionManager.slot))
            }
            console.logUint(positionManagerSize);
        }
    }
    
    /**
     * @notice Check token balances and allowances for the current sender
     * @param token0 The first token address
     * @param token1 The second token address
     */
    function checkBalancesAndAllowances(address token0, address token1) internal view {
        address sender = msg.sender;
        
        console.logString("Address being checked for balances and allowances: ");
        console.logAddress(sender);
        
        // Check token0 balance
        uint256 token0Balance = IERC20(token0).balanceOf(sender);
        console.logString("Token0 balance check:");
        console.logString("- Token address: ");
        console.logAddress(token0);
        console.logString("- Balance owner: ");
        console.logAddress(sender);
        console.logString("- Balance: ");
        console.logUint(token0Balance);
        console.logString("- Required: ");
        console.logUint(amount0);
        
        if (token0Balance < amount0) {
            console.logString("WARNING: Insufficient token0 balance!");
        }
        
        // Check token1 balance
        uint256 token1Balance = IERC20(token1).balanceOf(sender);
        console.logString("Token1 balance check:");
        console.logString("- Token address: ");
        console.logAddress(token1);
        console.logString("- Balance owner: ");
        console.logAddress(sender);
        console.logString("- Balance: ");
        console.logUint(token1Balance);
        console.logString("- Required: ");
        console.logUint(amount1);
        
        if (token1Balance < amount1) {
            console.logString("WARNING: Insufficient token1 balance!");
        }
        
        // Check allowances
        checkAllowances(token0, token1);
    }
    
    /**
     * @notice Check allowances granted to the position manager
     * @param token0 The first token address
     * @param token1 The second token address
     */
    function checkAllowances(address token0, address token1) internal view {
        address sender = msg.sender;
        
        // Check token0 allowance
        uint256 token0Allowance = IERC20(token0).allowance(sender, address(positionManager));
        console.logString("Token0 allowance check:");
        console.logString("- Token address: ");
        console.logAddress(token0);
        console.logString("- Owner address: ");
        console.logAddress(sender);
        console.logString("- Spender address: ");
        console.logAddress(address(positionManager));
        console.logString("- Allowance for position manager: ");
        console.logUint(token0Allowance);
        console.logString("- Required: ");
        console.logUint(amount0);
        
        if (token0Allowance < amount0) {
            console.logString("WARNING: Insufficient token0 allowance!");
        }
        
        // Check token1 allowance
        uint256 token1Allowance = IERC20(token1).allowance(sender, address(positionManager));
        console.logString("Token1 allowance check:");
        console.logString("- Token address: ");
        console.logAddress(token1);
        console.logString("- Owner address: ");
        console.logAddress(sender);
        console.logString("- Spender address: ");
        console.logAddress(address(positionManager));
        console.logString("- Allowance for position manager: ");
        console.logUint(token1Allowance);
        console.logString("- Required: ");
        console.logUint(amount1);
        
        if (token1Allowance < amount1) {
            console.logString("WARNING: Insufficient token1 allowance!");
        }
    }
    
    /**
     * @notice Helper to convert address to string for logging
     */
    function addressToString(address addr) internal pure returns (string memory) {
        return vm.toString(addr);
    }
} 