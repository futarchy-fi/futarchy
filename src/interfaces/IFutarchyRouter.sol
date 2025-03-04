// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "./IERC20Extended.sol";
import {IFutarchyProposal} from "./IFutarchyProposal.sol";

/**
 * @title IFutarchyRouter
 * @notice Interface for the FutarchyRouter contract
 * @dev This interface provides functions to interact with the FutarchyRouter contract
 */
interface IFutarchyRouter {
    /**
     * @notice Transfers the collateral to the Router, splits the position and sends the ERC20 outcome tokens back to the user
     * @param proposal The Proposal to split
     * @param collateralToken The address of the ERC20 used as collateral
     * @param amount The amount of collateral to split
     */
    function splitPosition(
        IFutarchyProposal proposal,
        IERC20 collateralToken,
        uint256 amount
    ) external;

    /**
     * @notice Merges positions and sends the collateral tokens to the user
     * @param proposal The Proposal to merge
     * @param collateralToken The address of the ERC20 used as collateral
     * @param amount The amount of outcome tokens to merge
     */
    function mergePositions(
        IFutarchyProposal proposal,
        IERC20 collateralToken,
        uint256 amount
    ) external;

    /**
     * @notice Redeems positions and sends the collateral tokens to the user
     * @param proposal The Proposal to redeem
     * @param amount1 Amount to redeem for the first collateral
     * @param amount2 Amount to redeem for the second collateral
     */
    function redeemProposal(
        IFutarchyProposal proposal,
        uint256 amount1,
        uint256 amount2
    ) external;

    /**
     * @notice Redeems positions and sends the collateral tokens to the user
     * @param proposal The Proposal to redeem
     * @param collateralToken The address of the ERC20 used as collateral
     * @param amount Amount to redeem
     */
    function redeemPositions(
        IFutarchyProposal proposal,
        IERC20 collateralToken,
        uint256 amount
    ) external;

    /**
     * @notice Constructs a tokenId from a collateral token and an outcome collection
     * @param collateralToken The address of the ERC20 used as collateral
     * @param parentCollectionId The Conditional Tokens parent collection id
     * @param conditionId The id of the condition used to redeem
     * @param indexSet Index set of the outcome collection to combine with the parent outcome collection
     * @return The token id
     */
    function getTokenId(
        IERC20 collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256 indexSet
    ) external view returns (uint256);

    /**
     * @notice Helper function used to know the redeemable outcomes associated to a conditionId
     * @param conditionId The id of the condition
     * @return An array of outcomes where a true value indicates that the outcome is redeemable
     */
    function getWinningOutcomes(bytes32 conditionId) external view returns (bool[] memory);
} 