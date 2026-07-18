// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { Order, Side } from "./OrderStructs.sol";

library OrderMath {
    /// @notice Returns the incremental taker amount owed for a cumulative maker-amount fill.
    /// @dev Cumulative ceiling rounding favors the resting maker without overcharging across repeated partial fills.
    function incrementalTakingAmount(
        uint256 filledBefore,
        uint256 makingAmount,
        uint256 makerAmount,
        uint256 takerAmount
    ) internal pure returns (uint256) {
        uint256 filledAfter = filledBefore + makingAmount;
        uint256 takingBefore = Math.mulDiv(filledBefore, takerAmount, makerAmount, Math.Rounding.Ceil);
        uint256 takingAfter = Math.mulDiv(filledAfter, takerAmount, makerAmount, Math.Rounding.Ceil);
        return takingAfter - takingBefore;
    }

    /// @notice Returns whether two opposite-side orders cross, without overflowing 256-bit multiplication.
    function isCrossing(Order memory first, Order memory second) internal pure returns (bool) {
        Order memory buy = first.side == Side.BUY ? first : second;
        Order memory sell = first.side == Side.SELL ? first : second;

        // buy.maker / buy.taker >= sell.taker / sell.maker
        return _productGte(buy.makerAmount, sell.makerAmount, buy.takerAmount, sell.takerAmount);
    }

    function _productGte(uint256 a, uint256 b, uint256 c, uint256 d) private pure returns (bool) {
        (uint256 leftHigh, uint256 leftLow) = _fullProduct(a, b);
        (uint256 rightHigh, uint256 rightLow) = _fullProduct(c, d);
        return leftHigh > rightHigh || (leftHigh == rightHigh && leftLow >= rightLow);
    }

    function _fullProduct(uint256 a, uint256 b) private pure returns (uint256 high, uint256 low) {
        assembly ("memory-safe") {
            let mm := mulmod(a, b, not(0))
            low := mul(a, b)
            high := sub(sub(mm, low), lt(mm, low))
        }
    }
}
