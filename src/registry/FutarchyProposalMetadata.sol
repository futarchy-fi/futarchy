// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract FutarchyProposalMetadata is Ownable, Initializable {
    address public proposalAddress;
    string public displayNameQuestion;
    string public displayNameEvent;
    string public description;
    string public metadata;
    string public metadataURI;

    address public editor;

    event MetadataUpdated(string displayNameQuestion, string displayNameEvent, string description);
    event ExtendedMetadataUpdated(string metadata, string metadataURI);
    event EditorSet(address indexed newEditor);
    event EditorRevoked(address indexed oldEditor);

    modifier onlyOwnerOrEditor() {
        require(msg.sender == owner() || msg.sender == editor, "Not owner or editor");
        _;
    }

    constructor() Ownable(msg.sender) {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        address proposalAddress_,
        string memory displayNameQuestion_,
        string memory displayNameEvent_,
        string memory description_,
        string memory metadata_,
        string memory metadataURI_
    ) external initializer {
        _transferOwnership(owner_);
        proposalAddress = proposalAddress_;
        displayNameQuestion = displayNameQuestion_;
        displayNameEvent = displayNameEvent_;
        description = description_;
        metadata = metadata_;
        metadataURI = metadataURI_;
    }

    function setEditor(address editor_) external onlyOwner {
        editor = editor_;
        emit EditorSet(editor_);
    }

    function revokeEditor() external onlyOwner {
        address oldEditor = editor;
        editor = address(0);
        emit EditorRevoked(oldEditor);
    }

    function updateMetadata(
        string memory displayNameQuestion_,
        string memory displayNameEvent_,
        string memory description_
    ) external onlyOwnerOrEditor {
        displayNameQuestion = displayNameQuestion_;
        displayNameEvent = displayNameEvent_;
        description = description_;
        emit MetadataUpdated(displayNameQuestion_, displayNameEvent_, description_);
    }

    function updateExtendedMetadata(string memory metadata_, string memory metadataURI_) external onlyOwnerOrEditor {
        metadata = metadata_;
        metadataURI = metadataURI_;
        emit ExtendedMetadataUpdated(metadata_, metadataURI_);
    }
}
