// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { Order } from "./libraries/OrderStructs.sol";
import { Trading } from "./mixins/Trading.sol";

/// @title ConditionalExchange
/// @notice Permissionless limit-order settlement for registered wrapped ERC-20 conditional-token pairs.
contract ConditionalExchange is Trading, Pausable, ReentrancyGuard {
    constructor(address initialOwner) Trading(initialOwner) { }

    function pauseTrading() external onlyOwner {
        _pause();
    }

    function unpauseTrading() external onlyOwner {
        _unpause();
    }

    function fillOrder(Order memory order, uint256 fillAmount) external nonReentrant whenNotPaused {
        _fillOrder(order, fillAmount, msg.sender);
    }

    function fillOrders(Order[] memory orders, uint256[] memory fillAmounts) external nonReentrant whenNotPaused {
        _fillOrders(orders, fillAmounts, msg.sender);
    }

    function matchOrders(
        Order memory takerOrder,
        Order[] memory makerOrders,
        uint256 takerFillAmount,
        uint256[] memory makerFillAmounts
    ) external nonReentrant whenNotPaused {
        _matchOrders(takerOrder, makerOrders, takerFillAmount, makerFillAmounts);
    }
}
