Here are clear, step-by-step instructions for creating a passthrough router that interfaces with the provided Uniswap V3 implementation. This router will closely mirror the swap function but explicitly requires a pool address as an input parameter.

---

## Architectural Decisions:

**Objective**:  
- Create a minimalistic passthrough router compatible with the provided UniswapV3Pool implementation.
- The router exposes a simplified swap API similar to the underlying pool's swap function, adding only the explicit `pool` address parameter.

**Key Design Points**:  
- Stateless Router: No liquidity management or additional state.
- Compatibility: Router only calls the provided `swap` function from the given UniswapV3Pool instance.
- Security: Delegate token custody, callbacks, and reentrancy protection to the underlying pool.

---

## Steps to Implementation:

### Step 1: Define Router Interface

The router interface closely mirrors the existing swap function but explicitly adds the pool address:

```solidity
interface IUniswapV3PassthroughRouter {
    function swap(
        address pool,
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}
```

### Step 2: Implement Router Contract

Create a simple passthrough router contract:

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import './interfaces/IUniswapV3Pool.sol';
import './interfaces/callback/IUniswapV3SwapCallback.sol';

contract UniswapV3PassthroughRouter is IUniswapV3PassthroughRouter, IUniswapV3SwapCallback {
    
    // Swap execution through a specified UniswapV3Pool
    function swap(
        address pool,
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external override returns (int256 amount0, int256 amount1) {
        (amount0, amount1) = IUniswapV3Pool(pool).swap(
            recipient,
            zeroForOne,
            amountSpecified,
            sqrtPriceLimitX96,
            data
        );
    }

    // Swap callback forwarding (necessary to satisfy callback requirements)
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        // Forward callback responsibility back to caller
        // Typically the caller would handle token transfers here
    }
}
```

### Step 3: Callback Considerations

The `uniswapV3SwapCallback` must implement token transfers. Clarify the following critical questions before implementation:

- Who should handle token transfers:  
  - **Option A (Recommended)**: Caller handles token transfers within the router callback.
  - **Option B**: Router directly handles token transfers (requires approval logic).

**Recommended clarification**:
- Should the router forward the callback data to the external caller or perform transfers internally?

Example Callback Implementation (forwarding to caller):

```solidity
function uniswapV3SwapCallback(
    int256 amount0Delta,
    int256 amount1Delta,
    bytes calldata data
) external override {
    // Decode sender from data
    address sender = abi.decode(data, (address));

    if (amount0Delta > 0) {
        IERC20Minimal(IUniswapV3Pool(msg.sender).token0()).transferFrom(sender, msg.sender, uint256(amount0Delta));
    }
    if (amount1Delta > 0) {
        IERC20Minimal(IUniswapV3Pool(msg.sender).token1()).transferFrom(sender, msg.sender, uint256(amount1Delta));
    }
}
```

---

## Next Steps:

**Please confirm or clarify:**
- Should the router perform transfers directly, or forward responsibility to the caller?
- Do you require additional router features such as multi-pool or batch swaps?

Once clarified, the detailed implementation can be finalized.
