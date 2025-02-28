# UniswapV3PassthroughRouter for Gnosis Chain

This repository contains an implementation of a minimalistic passthrough router for Uniswap V3 pools, specifically designed to be deployed on Gnosis Chain. The router acts as a simple interface to Uniswap V3 pools, providing only the swap functionality with an explicit pool address parameter.

## Overview

The UniswapV3PassthroughRouter is a stateless contract that:

1. Takes a pool address as an explicit parameter
2. Forwards the swap call to the pool
3. Handles the callback and token transfers
4. Returns the swap results back to the caller

## Architecture

The router implementation consists of the following components:

- `UniswapV3PassthroughRouter.sol`: The main router contract
- `interfaces/IUniswapV3PassthroughRouter.sol`: The router interface
- `interfaces/callback/IUniswapV3SwapCallback.sol`: The swap callback interface
- `interfaces/IUniswapV3Pool.sol`: The Uniswap V3 pool interface
- `interfaces/IERC20Minimal.sol`: A minimal ERC20 interface for token transfers

## Implementation Details

The router follows a simple design principle:

1. It exposes a `swap` function that accepts a pool address and the standard Uniswap V3 swap parameters
2. It forwards these parameters to the specified pool
3. It implements the required callback to handle token transfers
4. It returns the swap result (token deltas) to the caller

### Token Transfers

When a swap is executed, the router's callback:
- Decodes the original caller's address from the callback data
- Transfers tokens from the original caller to the pool using `transferFrom`
- This requires the user to approve the router to spend their tokens before executing a swap

## Deployment to Gnosis Chain

### Prerequisites

1. [Foundry](https://getfoundry.sh/) installed
2. An account with funds on Gnosis Chain
3. A Gnosisscan API key for contract verification

### Setup

1. Clone the repository:
   ```
   git clone <repository_url>
   cd futarchy
   ```

2. Install dependencies:
   ```
   forge install
   ```

3. Create a `.env` file based on the `.env.example` template:
   ```
   cp .env.example .env
   ```

4. Edit the `.env` file with your private key and Gnosisscan API key:
   ```
   PRIVATE_KEY=your_private_key_here
   ETHERSCAN_KEY=your_gnosisscan_api_key_here
   ```

### Deployment

1. Compile the contracts:
   ```
   forge build
   ```

2. Deploy to Gnosis Chain:
   ```
   forge script script/DeployUniswapV3PassthroughRouter.s.sol:DeployUniswapV3PassthroughRouter --rpc-url gnosis --broadcast --verify
   ```

3. If verification fails, you can manually verify the contract:
   ```
   forge verify-contract <DEPLOYED_ADDRESS> src/UniswapV3PassthroughRouter.sol:UniswapV3PassthroughRouter --chain gnosis --etherscan-api-key $ETHERSCAN_KEY
   ```

## Usage

Once deployed, the router can be used to execute swaps through any Uniswap V3 pool on Gnosis Chain:

```solidity
// Approve the router to spend your tokens first
IERC20(tokenAddress).approve(routerAddress, amount);

// Execute the swap
(int256 amount0, int256 amount1) = IUniswapV3PassthroughRouter(routerAddress).swap(
    poolAddress,       // The Uniswap V3 pool address
    recipient,         // Address to receive the output tokens
    zeroForOne,        // Direction of the swap (true = token0 to token1)
    amountSpecified,   // Amount to swap (positive = exact input, negative = exact output)
    sqrtPriceLimitX96, // Price limit
    bytes("")          // Optional data
);
```

### JavaScript/TypeScript Example

Here's an example of how to use the router from JavaScript/TypeScript:

```typescript
import { ethers } from 'ethers';
import IUniswapV3PassthroughRouter from './artifacts/src/interfaces/IUniswapV3PassthroughRouter.sol/IUniswapV3PassthroughRouter.json';
import IERC20 from './artifacts/src/interfaces/IERC20Minimal.sol/IERC20Minimal.json';

async function executeSwap() {
  // Connect to the network
  const provider = new ethers.providers.JsonRpcProvider('https://rpc.gnosischain.com');
  const wallet = new ethers.Wallet(privateKey, provider);
  
  // Contract instances
  const router = new ethers.Contract(routerAddress, IUniswapV3PassthroughRouter.abi, wallet);
  const token = new ethers.Contract(tokenAddress, IERC20.abi, wallet);
  
  // Approve router to spend tokens
  const amount = ethers.utils.parseUnits('10', 18); // 10 tokens with 18 decimals
  await token.approve(routerAddress, amount);
  
  // Execute swap
  const tx = await router.swap(
    poolAddress,                   // Uniswap V3 pool address
    wallet.address,                // Recipient of output tokens
    true,                          // zeroForOne (true = token0 to token1)
    amount,                        // amountSpecified (positive = exact input)
    0,                             // sqrtPriceLimitX96 (0 = no limit)
    '0x'                           // data (empty)
  );
  
  // Wait for the transaction to be mined
  const receipt = await tx.wait();
  console.log('Swap executed:', receipt.transactionHash);
}
```

## Testing

The implementation includes a test suite that verifies the router's functionality. To run the tests:

```
forge test -vvv
```

The test creates a mock Uniswap V3 pool and ERC20 tokens to simulate the swap process and verify that the router correctly handles the callback and token transfers.

## Security Considerations

- The router delegates most of the security to the underlying Uniswap V3 pools
- Users should verify the pool address before executing swaps to prevent interacting with malicious pools
- The router uses `transferFrom` to move tokens, so users must approve the router before swapping

## License

This project is licensed under GPL-3.0. 