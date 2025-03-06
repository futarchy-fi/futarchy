// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IFutarchyProposal} from "../../src/interfaces/IFutarchyProposal.sol";
import {ISushiswapV3PositionManager} from "../../src/interfaces/ISushiswapV3PositionManager.sol";
import {IERC20} from "../../src/interfaces/IERC20Extended.sol";

/**
 * @title DeployV3Pools
 * @notice Script to deploy SushiSwap v3 pools for futarchy conditional tokens
 * @dev Creates v3 pools for token1yes/token2yes and token1no/token2no pairs
 *      with 0.1% fee tier and concentrated liquidity
 */
contract DeployV3Pools is Script {
    ISushiswapV3PositionManager public positionManager;
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
        positionManager = ISushiswapV3PositionManager(vm.envAddress("NONFUNGIBLE_POSITION_MANAGER"));
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
        console.log("- Token0: ");
        console.logAddress(token0);
        console.log("- Token1: ");
        console.logAddress(token1);

        // Step 1: Approve tokens for the position manager
        console.log("Approving tokens...");
        IERC20(token0).approve(address(positionManager), amount0);
        IERC20(token1).approve(address(positionManager), amount1);

        // Step 2: Initialize the pool with a specific price if it doesn't exist
        console.log("Initializing pool...");
        address pool = positionManager.createAndInitializePoolIfNecessary(
            token0,
            token1,
            feeTier,
            SQRT_PRICE_X96
        );
        console.log("Pool initialized at: ");
        console.logAddress(pool);

        // Step 3: Add liquidity by minting a position
        console.log("Adding liquidity...");
        ISushiswapV3PositionManager.MintParams memory params = ISushiswapV3PositionManager.MintParams({
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
            console.log("- NFT Token ID: ");
            console.logUint(tokenId);
            console.log("- Liquidity: ");
            console.logUint(uint256(liquidity));
            console.log("- Token0 used: ");
            console.logUint(amount0Used);
            console.log("- Token1 used: ");
            console.logUint(amount1Used);
        } catch Error(string memory reason) {
            console.log("Failed to add liquidity:");
            console.log("- Reason: ");
            console.logString(reason);
        } catch (bytes memory) {
            console.log("Failed to add liquidity (unknown error)");
        }
    }
    
    /**
     * @notice Helper to convert address to string for logging
     */
    function addressToString(address addr) internal pure returns (string memory) {
        return vm.toString(addr);
    }
} 