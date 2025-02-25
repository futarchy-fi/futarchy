// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "./IERC20Extended.sol";
import {IFutarchyProposal} from "./IFutarchyProposal.sol";

/**
 * @title IFutarchyRouter
 * @dev Interface for the FutarchyRouter contract that helps manage operations with proposals
 */
interface IFutarchyRouter {
    /**
     * @dev Retrieves all outcome tokens for a proposal
     * @param proposal The proposal contract address
     * @return outcomeTokens The array of outcome token addresses
     */
    function getOutcomeTokens(address proposal) external view returns (IERC20[] memory outcomeTokens);
    
    /**
     * @dev Fetches the YES token addresses for both collateral tokens
     * @param proposal The proposal contract address
     * @return yesToken1 The YES token for the first collateral
     * @return yesToken2 The YES token for the second collateral
     */
    function getYesTokens(IFutarchyProposal proposal) external view returns (IERC20 yesToken1, IERC20 yesToken2);
    
    /**
     * @dev Fetches the NO token addresses for both collateral tokens
     * @param proposal The proposal contract address
     * @return noToken1 The NO token for the first collateral
     * @return noToken2 The NO token for the second collateral
     */
    function getNoTokens(IFutarchyProposal proposal) external view returns (IERC20 noToken1, IERC20 noToken2);
    
    /**
     * @dev Approves tokens for spending by external contracts
     * @param token The token to approve
     * @param spender The address allowed to spend the tokens
     * @param amount The amount to approve
     * @return success Whether the approval was successful
     */
    function approveToken(IERC20 token, address spender, uint256 amount) external returns (bool success);
    
    /**
     * @dev Resolves a proposal
     * @param proposal The proposal to resolve
     */
    function resolveProposal(IFutarchyProposal proposal) external;
} 