# UniswapV3PassthroughRouter

This is a minimal implementation of a Uniswap V3 passthrough router. The router is designed to be a simple interface to Uniswap V3 pools, providing only the swap functionality with an explicit pool address parameter.

## Overview

The UniswapV3PassthroughRouter is a stateless contract that:

1. Takes a pool address as an explicit parameter
2. Forwards the swap call to the pool
3. Handles the callback and token transfers
4. Returns the swap results back to the caller

## Contracts

- `UniswapV3PassthroughRouter.sol`: The main router contract
- `interfaces/IUniswapV3PassthroughRouter.sol`: The router interface
- `interfaces/callback/IUniswapV3SwapCallback.sol`: The swap callback interface
- `interfaces/IUniswapV3Pool.sol`: The Uniswap V3 pool interface
- `interfaces/IERC20Minimal.sol`: A minimal ERC20 interface for token transfers

## Deployment to Gnosis Chain

### Prerequisites

1. Set up a `.env` file with the following variables:
   ```
   PRIVATE_KEY=your_private_key
   ETHERSCAN_KEY=your_gnosisscan_api_key
   ```

2. Make sure you have funds on Gnosis Chain for gas fees

### Deployment Steps

1. Compile the contracts:
   ```
   forge build
   ```

2. Deploy to Gnosis Chain:
   ```
   forge script script/deploy/DeployUniswapV3PassthroughRouter.s.sol:DeployUniswapV3PassthroughRouter --rpc-url gnosis --broadcast --verify
   ```

3. Verify the contract (if verification didn't work in the previous step):
   ```
   forge verify-contract <DEPLOYED_ADDRESS> src/UniswapV3PassthroughRouter.sol:UniswapV3PassthroughRouter --chain gnosis --etherscan-api-key $ETHERSCAN_KEY
   ```

## Usage

To use the router for swaps:

```solidity
// Approve the router to spend your tokens first
IERC20(tokenAddress).approve(routerAddress, amount);

// Execute the swap
IUniswapV3PassthroughRouter(routerAddress).swap(
    poolAddress,       // The Uniswap V3 pool address
    recipient,         // Address to receive the output tokens
    zeroForOne,        // Direction of the swap (true = token0 to token1)
    amountSpecified,   // Amount to swap (positive = exact input, negative = exact output)
    sqrtPriceLimitX96, // Price limit
    bytes("")          // Optional data
);
```

## Notes

- The router requires token approval from the user before executing swaps
- The user must provide a valid pool address
- All swap parameters are forwarded directly to the pool
- The router handles the swap callback internally by transferring tokens from the caller to the pool 