// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { Order, OrderStatus, Side } from "../libraries/OrderStructs.sol";
import { OrderMath } from "../libraries/OrderMath.sol";
import { Hashing } from "./Hashing.sol";
import { PairRegistry } from "./PairRegistry.sol";
import { Signatures } from "./Signatures.sol";

abstract contract Trading is Hashing, PairRegistry, Signatures {
    using SafeERC20 for IERC20;

    struct MatchState {
        bytes32[] makerOrderHashes;
        uint256[] makerTakingAmounts;
        uint256 totalTakerSpent;
        uint256 totalTakerReceived;
    }

    error ArrayLengthMismatch();
    error InvalidNonce();
    error InvalidOrderAmounts();
    error MakingAmountExceedsRemaining();
    error MismatchedTokenIds();
    error NotCrossing();
    error NotOrderMaker();
    error NotTaker();
    error OrderExpired();
    error OrderFilledOrCancelled();
    error TooLittleTakerAmount();
    error TooMuchTakerSpent();

    event OrderCancelled(bytes32 indexed orderHash);
    event OrderFilled(
        bytes32 indexed orderHash,
        address indexed maker,
        address indexed counterparty,
        address makerAsset,
        address takerAsset,
        uint256 makerAmountFilled,
        uint256 takerAmountFilled,
        uint256 fee
    );
    event OrdersMatched(
        bytes32 indexed takerOrderHash,
        address indexed takerOrderMaker,
        uint256 takerMakerAmountFilled,
        uint256 takerMakerAmountSpent,
        uint256 takerAmountReceived
    );
    event NonceIncremented(address indexed maker, uint256 newNonce);

    uint256 public constant CHARGED_FEE_RATE_BPS = 0;

    mapping(bytes32 orderHash => OrderStatus status) public orderStatus;
    mapping(address maker => uint256 nonce) public nonces;

    constructor(address initialOwner) PairRegistry(initialOwner) { }

    function getOrderStatus(bytes32 orderHash) external view returns (OrderStatus memory) {
        return orderStatus[orderHash];
    }

    function validateOrder(Order memory order) external view {
        _validateOrder(hashOrder(order), order);
    }

    function cancelOrder(Order memory order) external {
        if (order.maker != msg.sender) revert NotOrderMaker();

        bytes32 orderHash = hashOrder(order);
        OrderStatus storage status = orderStatus[orderHash];
        if (status.isFilledOrCancelled) revert OrderFilledOrCancelled();

        status.isFilledOrCancelled = true;
        emit OrderCancelled(orderHash);
    }

    function incrementNonce() external {
        uint256 newNonce = nonces[msg.sender] + 1;
        nonces[msg.sender] = newNonce;
        emit NonceIncremented(msg.sender, newNonce);
    }

    function _fillOrder(Order memory order, uint256 fillAmount, address counterparty) internal {
        bytes32 orderHash = hashOrder(order);
        _validateOrderForCaller(orderHash, order);
        (address makerAsset, address takerAsset) = _assets(order);
        uint256 takingAmount = _consumeOrder(orderHash, order, fillAmount);

        IERC20(takerAsset).safeTransferFrom(counterparty, order.maker, takingAmount);
        IERC20(makerAsset).safeTransferFrom(order.maker, counterparty, fillAmount);

        emit OrderFilled(orderHash, order.maker, counterparty, makerAsset, takerAsset, fillAmount, takingAmount, 0);
    }

    function _fillOrders(Order[] memory orders, uint256[] memory fillAmounts, address counterparty) internal {
        if (orders.length != fillAmounts.length) revert ArrayLengthMismatch();
        for (uint256 i; i < orders.length; ++i) {
            _fillOrder(orders[i], fillAmounts[i], counterparty);
        }
    }

    function _matchOrders(
        Order memory takerOrder,
        Order[] memory makerOrders,
        uint256 takerFillAmount,
        uint256[] memory makerFillAmounts
    ) internal {
        uint256 length = makerOrders.length;
        if (length == 0 || length != makerFillAmounts.length) revert ArrayLengthMismatch();

        bytes32 takerOrderHash = hashOrder(takerOrder);
        _validateOrderForCaller(takerOrderHash, takerOrder);
        (address takerMakerAsset, address takerAsset) = _assets(takerOrder);
        uint256 takerMinimumReceived = _incrementalTakingAmount(takerOrderHash, takerOrder, takerFillAmount);

        MatchState memory state = _prepareMakerOrders(takerOrder, makerOrders, makerFillAmounts);

        if (state.totalTakerSpent > takerFillAmount) revert TooMuchTakerSpent();
        if (state.totalTakerReceived < takerMinimumReceived) revert TooLittleTakerAmount();
        _consumeOrder(takerOrderHash, takerOrder, takerFillAmount);

        for (uint256 i; i < length; ++i) {
            Order memory makerOrder = makerOrders[i];
            uint256 makerFillAmount = makerFillAmounts[i];
            uint256 makerTakingAmount = state.makerTakingAmounts[i];

            IERC20(takerAsset).safeTransferFrom(makerOrder.maker, takerOrder.maker, makerFillAmount);
            IERC20(takerMakerAsset).safeTransferFrom(takerOrder.maker, makerOrder.maker, makerTakingAmount);

            emit OrderFilled(
                state.makerOrderHashes[i],
                makerOrder.maker,
                takerOrder.maker,
                takerAsset,
                takerMakerAsset,
                makerFillAmount,
                makerTakingAmount,
                0
            );
        }

        emit OrderFilled(
            takerOrderHash,
            takerOrder.maker,
            address(this),
            takerMakerAsset,
            takerAsset,
            takerFillAmount,
            state.totalTakerReceived,
            0
        );
        emit OrdersMatched(
            takerOrderHash, takerOrder.maker, takerFillAmount, state.totalTakerSpent, state.totalTakerReceived
        );
    }

    function _prepareMakerOrders(Order memory takerOrder, Order[] memory makerOrders, uint256[] memory makerFillAmounts)
        private
        returns (MatchState memory state)
    {
        uint256 length = makerOrders.length;
        state.makerOrderHashes = new bytes32[](length);
        state.makerTakingAmounts = new uint256[](length);

        for (uint256 i; i < length; ++i) {
            Order memory makerOrder = makerOrders[i];
            if (makerOrder.side == takerOrder.side) revert NotCrossing();
            if (makerOrder.tokenId != takerOrder.tokenId) revert MismatchedTokenIds();
            if (!OrderMath.isCrossing(takerOrder, makerOrder)) revert NotCrossing();

            bytes32 makerOrderHash = hashOrder(makerOrder);
            _validateOrderForCaller(makerOrderHash, makerOrder);
            uint256 makerTakingAmount = _consumeOrder(makerOrderHash, makerOrder, makerFillAmounts[i]);

            state.makerOrderHashes[i] = makerOrderHash;
            state.makerTakingAmounts[i] = makerTakingAmount;
            state.totalTakerSpent += makerTakingAmount;
            state.totalTakerReceived += makerFillAmounts[i];
        }
    }

    function _validateOrderForCaller(bytes32 orderHash, Order memory order) private view {
        if (order.taker != address(0) && order.taker != msg.sender) revert NotTaker();
        _validateOrder(orderHash, order);
    }

    function _validateOrder(bytes32 orderHash, Order memory order) private view {
        if (order.maker == address(0) || order.makerAmount == 0 || order.takerAmount == 0) {
            revert InvalidOrderAmounts();
        }
        if (order.expiration != 0 && order.expiration < block.timestamp) revert OrderExpired();
        if (order.nonce != nonces[order.maker]) revert InvalidNonce();
        if (orderStatus[orderHash].isFilledOrCancelled) revert OrderFilledOrCancelled();

        getPair(order.tokenId);
        validateOrderSignature(orderHash, order);

        // feeRateBps is the maker's signed maximum. V1 charges zero, which is always within that maximum.
        assert(CHARGED_FEE_RATE_BPS <= order.feeRateBps);
    }

    function _consumeOrder(bytes32 orderHash, Order memory order, uint256 makingAmount)
        private
        returns (uint256 takingAmount)
    {
        takingAmount = _incrementalTakingAmount(orderHash, order, makingAmount);

        OrderStatus storage status = orderStatus[orderHash];
        uint256 remaining = status.remaining == 0 ? order.makerAmount : status.remaining;
        remaining -= makingAmount;
        status.remaining = remaining;
        if (remaining == 0) status.isFilledOrCancelled = true;
    }

    function _incrementalTakingAmount(bytes32 orderHash, Order memory order, uint256 makingAmount)
        private
        view
        returns (uint256)
    {
        if (makingAmount == 0) revert InvalidOrderAmounts();

        OrderStatus storage status = orderStatus[orderHash];
        uint256 remaining = status.remaining == 0 ? order.makerAmount : status.remaining;
        if (makingAmount > remaining) revert MakingAmountExceedsRemaining();

        uint256 filledBefore = order.makerAmount - remaining;
        return OrderMath.incrementalTakingAmount(filledBefore, makingAmount, order.makerAmount, order.takerAmount);
    }

    function _assets(Order memory order) private view returns (address makerAsset, address takerAsset) {
        (address outcomeToken, address quoteToken) = getPair(order.tokenId);
        return order.side == Side.BUY ? (quoteToken, outcomeToken) : (outcomeToken, quoteToken);
    }
}
