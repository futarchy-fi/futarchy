// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import { Order, ORDER_TYPEHASH } from "../libraries/OrderStructs.sol";

abstract contract Hashing is EIP712 {
    constructor() EIP712("Futarchy Exchange", "1") { }

    function hashOrder(Order memory order) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH,
                    order.salt,
                    order.maker,
                    order.signer,
                    order.taker,
                    order.tokenId,
                    order.makerAmount,
                    order.takerAmount,
                    order.expiration,
                    order.nonce,
                    order.feeRateBps,
                    order.side,
                    order.signatureType
                )
            )
        );
    }

    function orderTypehash() external pure returns (bytes32) {
        return ORDER_TYPEHASH;
    }

    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }
}
