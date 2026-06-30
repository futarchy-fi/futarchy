// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import { FutarchyOrganizationMetadata } from "./FutarchyOrganizationMetadata.sol";

contract OrganizationMetadataFactory {
    address public immutable implementation;
    address public immutable proposalImplementation;

    event OrganizationMetadataCreated(address indexed metadata, string name);

    constructor(address implementation_, address proposalImplementation_) {
        implementation = implementation_;
        proposalImplementation = proposalImplementation_;
    }

    function createOrganizationMetadata(
        string memory companyName,
        string memory description,
        string memory metadata,
        string memory metadataURI
    ) external returns (address) {
        address clone = Clones.clone(implementation);
        FutarchyOrganizationMetadata(clone)
            .initialize(msg.sender, companyName, description, metadata, metadataURI, proposalImplementation);
        emit OrganizationMetadataCreated(clone, companyName);
        return clone;
    }
}
