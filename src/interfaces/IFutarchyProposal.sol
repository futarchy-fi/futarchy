// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "./IERC20Extended.sol";

/**
 * @title IFutarchyProposal
 * @dev Interface for the FutarchyProposal contract that represents a futarchy proposal
 */
interface IFutarchyProposal {
    /**
     * @dev Returns the name of the proposal
     * @return The proposal name
     */
    function marketName() external view returns (string memory);
    
    /**
     * @dev Returns a specific outcome name by index
     * @param index The outcome index
     * @return The outcome name
     */
    function outcomes(uint256 index) external view returns (string memory);
    
    /**
     * @dev Returns the number of outcomes
     * @return The number of outcomes
     */
    function numOutcomes() external view returns (uint256);
    
    /**
     * @dev Returns the conditional tokens conditionId
     * @return The condition ID
     */
    function conditionId() external view returns (bytes32);
    
    /**
     * @dev Returns the Reality.eth questionId
     * @return The question ID
     */
    function questionId() external view returns (bytes32);
    
    /**
     * @dev Returns the first collateral token
     * @return The collateral token
     */
    function collateralToken1() external view returns (IERC20);
    
    /**
     * @dev Returns the second collateral token
     * @return The collateral token
     */
    function collateralToken2() external view returns (IERC20);
    
    /**
     * @dev Returns the wrapped ERC20 token for a specific outcome
     * @param index The outcome index
     * @return wrapped1155 The wrapped token
     * @return data The token data
     */
    function wrappedOutcome(uint256 index) external view returns (IERC20 wrapped1155, bytes memory data);
    
    /**
     * @dev Resolves the proposal
     */
    function resolve() external;
} 