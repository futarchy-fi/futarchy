// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import { Order, SignatureType } from "../libraries/OrderStructs.sol";

abstract contract Signatures {
    error InvalidSignature();
    error UnsupportedSignatureType(SignatureType signatureType);

    function validateOrderSignature(bytes32 orderHash, Order memory order) public view {
        if (order.maker != order.signer) revert InvalidSignature();

        if (order.signatureType == SignatureType.EOA) {
            (address recovered, ECDSA.RecoverError error,) = ECDSA.tryRecover(orderHash, order.signature);
            if (error != ECDSA.RecoverError.NoError || recovered != order.signer) revert InvalidSignature();
            return;
        }

        if (order.signatureType == SignatureType.EIP1271) {
            if (
                order.signer.code.length == 0
                    || !SignatureChecker.isValidERC1271SignatureNow(order.signer, orderHash, order.signature)
            ) {
                revert InvalidSignature();
            }
            return;
        }

        revert UnsupportedSignatureType(order.signatureType);
    }
}
