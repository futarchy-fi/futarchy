// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "./IERC20Extended.sol";

/**
 * @title IFutarchyFactory
 * @dev Interface for the FutarchyFactory contract that creates futarchy proposals
 */
interface IFutarchyFactory {
    /**
     * @dev Parameters for creating a new proposal
     * @param marketName The name of the proposal
     * @param collateralToken1 First collateral token
     * @param collateralToken2 Second collateral token
     * @param category Reality question category
     * @param lang Reality question language
     * @param minBond Min bond to use on Reality
     * @param openingTime Reality question opening time
     */
    struct CreateProposalParams {
        string marketName;
        IERC20 collateralToken1;
        IERC20 collateralToken2;
        string category;
        string lang;
        uint256 minBond;
        uint32 openingTime;
    }

    /**
     * @dev Creates a new futarchy proposal
     * @param params Parameters for the proposal
     * @return The address of the newly created proposal
     */
    function createProposal(CreateProposalParams memory params) external returns (address);
    
    /**
     * @dev Returns the proposal at the given index
     * @param index The index in the proposals array
     * @return The address of the proposal
     */
    function proposals(uint256 index) external view returns (address);
} 