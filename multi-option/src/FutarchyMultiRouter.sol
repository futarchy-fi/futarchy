// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IConditionalTokens, IERC20, IWrapped1155Factory} from "./Interfaces.sol";
import {FutarchyMultiProposal} from "./FutarchyMultiProposal.sol";

interface IProposalRegistry {
    function isProposal(address proposal) external view returns (bool);
}

/// @notice Split, merge and redeem the outcome tokens of multi-option proposals. Adapted from Seer's
/// FutarchyRouter (two outcomes). For a nested proposal the "collateral" side of each operation is the
/// parent option's wrapped token instead of the collateral token itself.
contract FutarchyMultiRouter {
    IConditionalTokens public immutable conditionalTokens;
    IWrapped1155Factory public immutable wrapped1155Factory;
    IProposalRegistry public immutable factory;

    constructor(
        IConditionalTokens _conditionalTokens,
        IWrapped1155Factory _wrapped1155Factory,
        IProposalRegistry _factory
    ) {
        conditionalTokens = _conditionalTokens;
        wrapped1155Factory = _wrapped1155Factory;
        factory = _factory;
    }

    /// @dev The router trusts the proposal's view functions (tokens, ids, collaterals). Only proposals
    /// created by the factory are accepted, so a made-up proposal cannot point it at other tokens.
    modifier onlyFactoryProposal(FutarchyMultiProposal proposal) {
        require(factory.isProposal(address(proposal)), "unknown proposal");
        _;
    }

    /// @notice Turn `amount` of collateral (or of the parent option's token) into `amount` of every option's token.
    function splitPosition(FutarchyMultiProposal proposal, IERC20 collateralToken, uint256 amount)
        external
        onlyFactoryProposal(proposal)
    {
        uint256 n = proposal.numOutcomes();
        uint256 offset = proposal.collateralIndex(collateralToken) * n;
        bytes32 parentCollectionId = proposal.parentCollectionId();
        bytes32 conditionId = proposal.conditionId();

        if (parentCollectionId == bytes32(0)) {
            require(collateralToken.transferFrom(msg.sender, address(this), amount), "collateral transfer failed");
            require(collateralToken.approve(address(conditionalTokens), amount), "collateral approve failed");
        } else {
            // The parent option's tokens are burnt to mint the child tokens, so unwrap them first.
            (IERC20 parentToken, bytes memory parentData) = proposal.parentWrappedOutcome(collateralToken);
            uint256 parentId = conditionalTokens.getPositionId(address(collateralToken), parentCollectionId);
            require(parentToken.transferFrom(msg.sender, address(this), amount), "parent token transfer failed");
            wrapped1155Factory.unwrap(address(conditionalTokens), parentId, amount, address(this), parentData);
        }

        conditionalTokens.splitPosition(
            address(collateralToken), parentCollectionId, conditionId, fullPartition(n), amount
        );

        for (uint256 i = 0; i < n; i++) {
            uint256 tokenId = getTokenId(collateralToken, parentCollectionId, conditionId, 1 << i);
            (IERC20 token, bytes memory data) = proposal.wrappedOutcome(offset + i);
            // Wrap to ERC20 and send to the user.
            conditionalTokens.safeTransferFrom(address(this), address(wrapped1155Factory), tokenId, amount, data);
            require(token.transfer(msg.sender, amount), "outcome token transfer failed");
        }
    }

    /// @notice Turn `amount` of every option's token back into `amount` of collateral (or of the parent option's token).
    function mergePositions(FutarchyMultiProposal proposal, IERC20 collateralToken, uint256 amount)
        external
        onlyFactoryProposal(proposal)
    {
        uint256 n = proposal.numOutcomes();
        uint256 offset = proposal.collateralIndex(collateralToken) * n;
        bytes32 parentCollectionId = proposal.parentCollectionId();
        bytes32 conditionId = proposal.conditionId();

        for (uint256 i = 0; i < n; i++) {
            uint256 tokenId = getTokenId(collateralToken, parentCollectionId, conditionId, 1 << i);
            (IERC20 token, bytes memory data) = proposal.wrappedOutcome(offset + i);
            require(token.transferFrom(msg.sender, address(this), amount), "outcome token transfer failed");
            wrapped1155Factory.unwrap(address(conditionalTokens), tokenId, amount, address(this), data);
        }

        conditionalTokens.mergePositions(
            address(collateralToken), parentCollectionId, conditionId, fullPartition(n), amount
        );

        if (parentCollectionId == bytes32(0)) {
            require(collateralToken.transfer(msg.sender, amount), "collateral transfer failed");
        } else {
            (IERC20 parentToken, bytes memory parentData) = proposal.parentWrappedOutcome(collateralToken);
            uint256 parentId = conditionalTokens.getPositionId(address(collateralToken), parentCollectionId);
            conditionalTokens.safeTransferFrom(address(this), address(wrapped1155Factory), parentId, amount, parentData);
            require(parentToken.transfer(msg.sender, amount), "parent token transfer failed");
        }
    }

    /// @notice After resolution, redeem `amount` of option `outcome`'s token. A winning option returns
    /// collateral (or the parent option's token, for a nested proposal); a losing one returns nothing.
    function redeemPositions(FutarchyMultiProposal proposal, IERC20 collateralToken, uint256 outcome, uint256 amount)
        external
        onlyFactoryProposal(proposal)
    {
        uint256 n = proposal.numOutcomes();
        require(outcome < n, "outcome out of range");
        bytes32 parentCollectionId = proposal.parentCollectionId();
        bytes32 conditionId = proposal.conditionId();

        {
            uint256 tokenId = getTokenId(collateralToken, parentCollectionId, conditionId, 1 << outcome);
            (IERC20 token, bytes memory data) =
                proposal.wrappedOutcome(proposal.collateralIndex(collateralToken) * n + outcome);
            require(token.transferFrom(msg.sender, address(this), amount), "outcome token transfer failed");
            wrapped1155Factory.unwrap(address(conditionalTokens), tokenId, amount, address(this), data);
        }

        uint256[] memory indexSets = new uint256[](1);
        indexSets[0] = 1 << outcome;

        if (parentCollectionId == bytes32(0)) {
            uint256 before = collateralToken.balanceOf(address(this));
            conditionalTokens.redeemPositions(address(collateralToken), parentCollectionId, conditionId, indexSets);
            uint256 received = collateralToken.balanceOf(address(this)) - before;
            if (received > 0) {
                require(collateralToken.transfer(msg.sender, received), "collateral transfer failed");
            }
        } else {
            uint256 parentId = conditionalTokens.getPositionId(address(collateralToken), parentCollectionId);
            uint256 before = conditionalTokens.balanceOf(address(this), parentId);
            conditionalTokens.redeemPositions(address(collateralToken), parentCollectionId, conditionId, indexSets);
            uint256 received = conditionalTokens.balanceOf(address(this), parentId) - before;
            if (received > 0) {
                (IERC20 parentToken, bytes memory parentData) = proposal.parentWrappedOutcome(collateralToken);
                conditionalTokens.safeTransferFrom(
                    address(this), address(wrapped1155Factory), parentId, received, parentData
                );
                require(parentToken.transfer(msg.sender, received), "parent token transfer failed");
            }
        }
    }

    function getTokenId(IERC20 collateralToken, bytes32 parentCollectionId, bytes32 conditionId, uint256 indexSet)
        public
        view
        returns (uint256)
    {
        bytes32 collectionId = conditionalTokens.getCollectionId(parentCollectionId, conditionId, indexSet);
        return conditionalTokens.getPositionId(address(collateralToken), collectionId);
    }

    /// @notice Which options won (payout above zero). Empty payouts mean the condition is not resolved.
    function getWinningOutcomes(bytes32 conditionId) external view returns (bool[] memory result) {
        result = new bool[](conditionalTokens.getOutcomeSlotCount(conditionId));
        for (uint256 i = 0; i < result.length; i++) {
            result[i] = conditionalTokens.payoutNumerators(conditionId, i) != 0;
        }
    }

    function fullPartition(uint256 n) internal pure returns (uint256[] memory partition) {
        partition = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            partition[i] = 1 << i;
        }
    }

    // ERC-1155 receiver hooks: ConditionalTokens mints positions to this contract during a split.
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 || interfaceId == 0x4e2312e0;
    }
}
