// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "./IERC20Extended.sol";

/**
 * @title IFutarchyProposal
 * @notice Interface for the FutarchyProposal contract
 */
interface IFutarchyProposal {
    /**
     * @notice Returns the first collateral token
     * @return The collateral token
     */
    function collateralToken1() external view returns (IERC20);

    /**
     * @notice Returns the second collateral token
     * @return The collateral token
     */
    function collateralToken2() external view returns (IERC20);

    /**
     * @notice Returns the condition IDs used for this proposal
     * @return The condition ID
     */
    function conditionId() external view returns (bytes32);

    /**
     * @notice Returns the parent collection ID
     * @return The parent collection ID
     */
    function parentCollectionId() external view returns (bytes32);

    /**
     * @notice Returns the parent market
     * @return The address of the parent proposal
     */
    function parentMarket() external view returns (address);

    /**
     * @notice Returns the index of the parent proposal's outcome token
     * @return The index of the parent proposal's outcome token
     */
    function parentOutcome() external view returns (uint256);

    /**
     * @notice Returns the wrapped token and data for a specific outcome index
     * @param index The outcome index
     * @return wrapped1155 The wrapped token
     * @return data The token data
     */
    function wrappedOutcome(uint256 index) external view returns (IERC20 wrapped1155, bytes memory data);

    /**
     * @notice Returns the wrapped token and data for the parent proposal
     * @return wrapped1155 The wrapped token
     * @return data The token data
     */
    function parentWrappedOutcome() external view returns (IERC20 wrapped1155, bytes memory data);

    /**
     * @notice Returns the total number of outcomes
     * @return The number of outcomes
     */
    function numOutcomes() external view returns (uint256);

    /**
     * @notice Helper function to resolve the proposal
     */
    function resolve() external;

    /**
     * @notice Returns the Reality.eth question ID
     * @return The question ID
     */
    function questionId() external view returns (bytes32);
} 