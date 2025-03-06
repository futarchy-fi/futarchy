// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

/**
 * @title IFutarchyProposal
 * @notice Interface for interacting with Futarchy proposal contracts
 * @dev Used to extract conditional tokens and other proposal details
 */
interface IFutarchyProposal {
    /**
     * @notice Returns the first collateral token
     * @return The address of the first collateral token
     */
    function collateral1() external view returns (address);

    /**
     * @notice Returns the second collateral token
     * @return The address of the second collateral token
     */
    function collateral2() external view returns (address);

    /**
     * @notice Returns the ConditionalTokens contract
     * @return The address of the ConditionalTokens contract
     */
    function conditionalTokens() external view returns (address);

    /**
     * @notice Returns the parent market index
     * @return The parent market index
     */
    function parentOutcome() external view returns (uint256);

    /**
     * @notice Returns the wrapped token for a specific outcome index
     * @param index The outcome index
     * @return The address of the wrapped outcome token
     */
    function wrappedOutcome(uint256 index) external view returns (address);

    /**
     * @notice Returns the parent wrapped outcome token and data
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
     * @notice Returns the proposal question
     * @return The proposal question
     */
    function question() external view returns (string memory);
} 