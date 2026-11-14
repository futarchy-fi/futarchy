// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "./Interfaces.sol";
import {FutarchyMultiRealityProxy} from "./FutarchyMultiRealityProxy.sol";

/// @notice One multi-option futarchy market: N mutually exclusive options over two collateral tokens
/// (for example NVDA and USDG). Every option has one outcome token per collateral, so there are 2N
/// outcome tokens. Adapted from Seer's FutarchyProposal, which is fixed to two options (Yes / No).
/// A proposal may be nested under one option of a parent proposal: its outcome tokens are then split
/// from, and redeem into, that parent option's tokens instead of the collateral. That is how a
/// catch-all option ("Other") is later divided into named candidates plus a new catch-all.
contract FutarchyMultiProposal {
    struct Params {
        bytes32 conditionId;
        bytes32 questionId;
        bytes32 parentCollectionId;
        IERC20 collateralToken1;
        IERC20 collateralToken2;
        /// Parent proposal, or address(0) when the tokens are split straight from collateral.
        address parentMarket;
        /// Option index in the parent proposal that this proposal divides.
        uint256 parentOutcome;
        string encodedQuestion;
    }

    string public marketName;
    /// Option names, in Reality.eth answer order. The last option is the catch-all.
    string[] public outcomes;
    /// Short symbols used in token names, same order as `outcomes`.
    string[] public outcomeSymbols;
    Params internal params;
    /// 2N wrapped ERC20s: index i is option i for collateral 1, index N + i is option i for collateral 2.
    IERC20[] internal wrapped1155;
    bytes[] internal tokenData;
    FutarchyMultiRealityProxy public immutable realityProxy;

    constructor(
        string memory _marketName,
        string[] memory _outcomes,
        string[] memory _outcomeSymbols,
        Params memory _params,
        IERC20[] memory _wrapped1155,
        bytes[] memory _tokenData,
        FutarchyMultiRealityProxy _realityProxy
    ) {
        require(_outcomes.length == _outcomeSymbols.length, "symbols length");
        require(_wrapped1155.length == 2 * _outcomes.length, "tokens length");
        require(_tokenData.length == _wrapped1155.length, "data length");
        marketName = _marketName;
        outcomes = _outcomes;
        outcomeSymbols = _outcomeSymbols;
        params = _params;
        wrapped1155 = _wrapped1155;
        tokenData = _tokenData;
        realityProxy = _realityProxy;
    }

    function numOutcomes() public view returns (uint256) {
        return outcomes.length;
    }

    function conditionId() external view returns (bytes32) {
        return params.conditionId;
    }

    function questionId() external view returns (bytes32) {
        return params.questionId;
    }

    function parentCollectionId() external view returns (bytes32) {
        return params.parentCollectionId;
    }

    function collateralToken1() external view returns (IERC20) {
        return params.collateralToken1;
    }

    function collateralToken2() external view returns (IERC20) {
        return params.collateralToken2;
    }

    function parentMarket() external view returns (address) {
        return params.parentMarket;
    }

    function parentOutcome() external view returns (uint256) {
        return params.parentOutcome;
    }

    function encodedQuestion() external view returns (string memory) {
        return params.encodedQuestion;
    }

    /// @param index 0..2N-1 (see `wrapped1155`).
    function wrappedOutcome(uint256 index) public view returns (IERC20 token, bytes memory data) {
        return (wrapped1155[index], tokenData[index]);
    }

    /// @notice Outcome token of option `outcome` for one of the two collateral tokens.
    function wrappedOutcomeFor(IERC20 collateralToken, uint256 outcome)
        public
        view
        returns (IERC20 token, bytes memory data)
    {
        require(outcome < numOutcomes(), "outcome out of range");
        return wrappedOutcome(collateralIndex(collateralToken) * numOutcomes() + outcome);
    }

    /// @notice The parent option's token for this collateral (zero address when there is no parent).
    function parentWrappedOutcome(IERC20 collateralToken) external view returns (IERC20 token, bytes memory data) {
        if (params.parentMarket != address(0)) {
            (token, data) =
                FutarchyMultiProposal(params.parentMarket).wrappedOutcomeFor(collateralToken, params.parentOutcome);
        }
    }

    /// @return 0 for collateral 1, 1 for collateral 2. Reverts for any other token.
    function collateralIndex(IERC20 collateralToken) public view returns (uint256) {
        if (collateralToken == params.collateralToken1) return 0;
        require(collateralToken == params.collateralToken2, "not a collateral of this proposal");
        return 1;
    }

    function resolve() external {
        realityProxy.resolve(this);
    }
}
