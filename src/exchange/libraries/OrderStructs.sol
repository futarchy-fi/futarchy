// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

bytes32 constant ORDER_TYPEHASH = keccak256(
    "Order(uint256 salt,address maker,address signer,address taker,uint256 tokenId,uint256 makerAmount,uint256 takerAmount,uint256 expiration,uint256 nonce,uint256 feeRateBps,uint8 side,uint8 signatureType)"
);

enum Side {
    BUY,
    SELL
}

enum SignatureType {
    EOA,
    UNUSED_1,
    UNUSED_2,
    EIP1271
}

struct Order {
    uint256 salt;
    address maker;
    address signer;
    address taker;
    uint256 tokenId;
    uint256 makerAmount;
    uint256 takerAmount;
    uint256 expiration;
    uint256 nonce;
    uint256 feeRateBps;
    Side side;
    SignatureType signatureType;
    bytes signature;
}

struct OrderStatus {
    bool isFilledOrCancelled;
    uint256 remaining;
}
