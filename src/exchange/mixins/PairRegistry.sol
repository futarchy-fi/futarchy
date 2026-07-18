// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Owner-curated registry of wrapped outcome tokens and their quote/collateral tokens.
abstract contract PairRegistry is Ownable {
    error InvalidPair();
    error PairAlreadyRegistered(address outcomeToken);
    error PairNotRegistered(uint256 tokenId);

    event PairRegistered(uint256 indexed tokenId, address indexed outcomeToken, address indexed quoteToken);

    mapping(address outcomeToken => address quoteToken) public quoteTokenOf;

    constructor(address initialOwner) Ownable(initialOwner) { }

    function registerPair(address outcomeToken, address quoteToken) external onlyOwner {
        if (
            outcomeToken == address(0) || quoteToken == address(0) || outcomeToken == quoteToken
                || outcomeToken.code.length == 0 || quoteToken.code.length == 0
        ) {
            revert InvalidPair();
        }
        if (quoteTokenOf[outcomeToken] != address(0)) revert PairAlreadyRegistered(outcomeToken);

        quoteTokenOf[outcomeToken] = quoteToken;
        emit PairRegistered(encodeTokenId(outcomeToken), outcomeToken, quoteToken);
    }

    function encodeTokenId(address token) public pure returns (uint256) {
        return uint256(uint160(token));
    }

    function getPair(uint256 tokenId) public view returns (address outcomeToken, address quoteToken) {
        outcomeToken = address(uint160(tokenId));
        if (tokenId != encodeTokenId(outcomeToken)) revert PairNotRegistered(tokenId);

        quoteToken = quoteTokenOf[outcomeToken];
        if (quoteToken == address(0)) revert PairNotRegistered(tokenId);
    }
}
