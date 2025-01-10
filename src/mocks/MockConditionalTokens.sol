// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IConditionalTokens.sol";

contract MockConditionalTokens is IConditionalTokens {
    mapping(bytes32 => uint256) public outcomeSlotCounts;
    mapping(bytes32 => uint256) private _payoutDenominators;
    mapping(bytes32 => uint256[]) private _payoutNumerators;
    mapping(bytes32 => ConditionData) private _conditions;

    struct ConditionData {
        address oracle;
        bytes32 questionId;
        uint256 outcomeSlotCount;
        uint256 payoutNumerator;
    }

    function prepareCondition(address oracle, bytes32 questionId, uint256 outcomeSlotCount) external override {
        bytes32 conditionId = getConditionId(oracle, questionId, outcomeSlotCount);
        outcomeSlotCounts[conditionId] = outcomeSlotCount;
        _conditions[conditionId] = ConditionData({
            oracle: oracle,
            questionId: questionId,
            outcomeSlotCount: outcomeSlotCount,
            payoutNumerator: 0
        });
    }

    function getConditionId(address oracle, bytes32 questionId, uint256 outcomeSlotCount)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(oracle, questionId, outcomeSlotCount));
    }

    function splitPosition(
        IERC20 collateralToken,
        bytes32, // parentCollectionId removed
        bytes32, // conditionId removed
        uint256[] calldata, // partition removed
        uint256 amount
    ) external {
        require(collateralToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
    }

    function mergePositions(
        IERC20 collateralToken,
        bytes32, // parentCollectionId removed
        bytes32, // conditionId removed
        uint256[] calldata, // partition removed
        uint256 amount
    ) external {
        require(collateralToken.transfer(msg.sender, amount), "Transfer failed");
    }

    function redeemPositions(
        IERC20 collateralToken,
        bytes32, // parentCollectionId removed
        bytes32 conditionId,
        uint256[] calldata // indexSets removed
    ) external {
        uint256 den = payoutDenominator(conditionId);
        require(den > 0, "Condition not resolved");
        uint256 amount = collateralToken.balanceOf(address(this));
        require(collateralToken.transfer(msg.sender, amount), "Transfer failed");
    }

    function setPayoutDenominator(bytes32 conditionId, uint256 denominator) external {
        _payoutDenominators[conditionId] = denominator;
    }

    function payoutDenominator(bytes32 conditionId) public view returns (uint256) {
        return _payoutDenominators[conditionId];
    }

    function getPositionId(IERC20 collateralToken, bytes32 collectionId) external pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(collateralToken, collectionId)));
    }

    function getCollectionId(bytes32 parentCollectionId, bytes32 conditionId, uint256 indexSet)
        external
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(parentCollectionId, conditionId, indexSet));
    }

    function getOutcomeSlotCount(bytes32 conditionId) external view returns (uint256) {
        return outcomeSlotCounts[conditionId];
    }

    function payoutNumerators(bytes32 conditionId) external view returns (uint256[] memory) {
        return _payoutNumerators[conditionId];
    }

    function reportPayouts(bytes32 conditionId, uint256[] calldata payouts) external {
        _payoutNumerators[conditionId] = payouts;
    }

    function conditions(bytes32 conditionId)
        external
        view
        returns (address oracle, bytes32 questionId, uint256 outcomeSlotCount, uint256 payoutNumerator)
    {
        ConditionData storage data = _conditions[conditionId];
        return (data.oracle, data.questionId, data.outcomeSlotCount, data.payoutNumerator);
    }
}
