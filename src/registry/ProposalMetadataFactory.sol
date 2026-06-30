// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import { FutarchyProposalMetadata } from "./FutarchyProposalMetadata.sol";

contract ProposalMetadataFactory {
    address public immutable implementation;

    event ProposalMetadataCreated(address indexed metadata, address indexed proposalAddress);

    constructor(address implementation_) {
        implementation = implementation_;
    }

    function createProposalMetadata(
        address proposalAddress,
        string memory displayNameQuestion,
        string memory displayNameEvent,
        string memory description,
        string memory metadata,
        string memory metadataURI
    ) external returns (address) {
        address clone = Clones.clone(implementation);
        FutarchyProposalMetadata(clone)
            .initialize(
                msg.sender, proposalAddress, displayNameQuestion, displayNameEvent, description, metadata, metadataURI
            );
        emit ProposalMetadataCreated(clone, proposalAddress);
        return clone;
    }
}
