// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IConditionalTokens, IRealityETH_v3_0} from "./Interfaces.sol";
import {FutarchyMultiProposal} from "./FutarchyMultiProposal.sol";

/// @notice Oracle of the multi-option conditions: reads the final Reality.eth answer and reports the
/// payout to ConditionalTokens. Adapted from Seer's FutarchyRealityProxy (two outcomes).
contract FutarchyMultiRealityProxy {
    IConditionalTokens public immutable conditionalTokens;
    IRealityETH_v3_0 public immutable realitio;

    constructor(IConditionalTokens _conditionalTokens, IRealityETH_v3_0 _realitio) {
        conditionalTokens = _conditionalTokens;
        realitio = _realitio;
    }

    /// @notice Resolve a proposal once its question is final. Anyone may call it.
    /// @dev The Reality.eth answer is the index of the winning option. An invalid answer, or any index
    /// outside the option list, pays the last option, which is the catch-all by convention. A wrong
    /// `proposal` cannot hurt another market: reportPayouts derives the condition from this contract's
    /// address, the question id and the number of options.
    function resolve(FutarchyMultiProposal proposal) external {
        bytes32 questionId = proposal.questionId();
        uint256 n = proposal.numOutcomes();

        uint256 answer = uint256(realitio.resultForOnceSettled(questionId));
        uint256[] memory payouts = new uint256[](n);
        payouts[answer < n ? answer : n - 1] = 1;

        conditionalTokens.reportPayouts(questionId, payouts);
    }
}
