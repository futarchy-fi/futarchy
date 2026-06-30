// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import { FutarchyProposalMetadata } from "./FutarchyProposalMetadata.sol";

contract FutarchyOrganizationMetadata is Ownable, Initializable {
    string public companyName;
    string public description;
    string public metadata;
    string public metadataURI;
    FutarchyProposalMetadata[] public proposals;

    address public editor;
    address public proposalImplementation;
    address public defaultLiquidityManager;
    address public defaultProposalSource;
    string public liquidityManagerMetadataURI;

    event CompanyInfoUpdated(string newName, string newDescription);
    event ExtendedMetadataUpdated(string metadata, string metadataURI);
    event ProposalAdded(address indexed proposalMetadata);
    event ProposalRemoved(address indexed proposalMetadata);
    event ProposalCreatedAndAdded(address indexed proposalMetadata, address indexed proposalAddress);
    event EditorSet(address indexed newEditor);
    event EditorRevoked(address indexed oldEditor);
    event ProposalImplementationSet(address indexed implementation);
    event DefaultLiquidityManagerSet(
        address indexed liquidityManager, address indexed proposalSource, string metadataURI
    );

    modifier onlyOwnerOrEditor() {
        require(msg.sender == owner() || msg.sender == editor, "Not owner or editor");
        _;
    }

    constructor() Ownable(msg.sender) {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        string memory companyName_,
        string memory description_,
        string memory metadata_,
        string memory metadataURI_,
        address proposalImplementation_
    ) external initializer {
        _initializeOrganization(owner_, companyName_, description_, metadata_, metadataURI_, proposalImplementation_);
    }

    function initializeWithDefaultLiquidityManager(
        address owner_,
        string memory companyName_,
        string memory description_,
        string memory metadata_,
        string memory metadataURI_,
        address proposalImplementation_,
        address defaultLiquidityManager_,
        address defaultProposalSource_,
        string memory liquidityManagerMetadataURI_
    ) external initializer {
        _initializeOrganization(owner_, companyName_, description_, metadata_, metadataURI_, proposalImplementation_);
        _setDefaultLiquidityManager(defaultLiquidityManager_, defaultProposalSource_, liquidityManagerMetadataURI_);
    }

    function setProposalImplementation(address implementation) external onlyOwner {
        proposalImplementation = implementation;
        emit ProposalImplementationSet(implementation);
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

    function updateCompanyInfo(string memory newName, string memory newDescription) external onlyOwnerOrEditor {
        companyName = newName;
        description = newDescription;
        emit CompanyInfoUpdated(newName, newDescription);
    }

    function updateExtendedMetadata(string memory metadata_, string memory metadataURI_) external onlyOwnerOrEditor {
        metadata = metadata_;
        metadataURI = metadataURI_;
        emit ExtendedMetadataUpdated(metadata_, metadataURI_);
    }

    function setDefaultLiquidityManager(
        address defaultLiquidityManager_,
        address defaultProposalSource_,
        string memory liquidityManagerMetadataURI_
    ) external onlyOwnerOrEditor {
        _setDefaultLiquidityManager(defaultLiquidityManager_, defaultProposalSource_, liquidityManagerMetadataURI_);
    }

    function addProposalMetadata(address proposalMetadata) external onlyOwnerOrEditor {
        proposals.push(FutarchyProposalMetadata(proposalMetadata));
        emit ProposalAdded(proposalMetadata);
    }

    function createAndAddProposalMetadata(
        address proposalAddress,
        string memory displayNameQuestion,
        string memory displayNameEvent,
        string memory description_,
        string memory metadata_,
        string memory metadataURI_
    ) external onlyOwnerOrEditor returns (address) {
        require(proposalImplementation != address(0), "Proposal implementation not set");

        address clone = Clones.clone(proposalImplementation);
        FutarchyProposalMetadata(clone)
            .initialize(
                msg.sender,
                proposalAddress,
                displayNameQuestion,
                displayNameEvent,
                description_,
                metadata_,
                metadataURI_
            );

        proposals.push(FutarchyProposalMetadata(clone));
        emit ProposalCreatedAndAdded(clone, proposalAddress);
        return clone;
    }

    function removeProposalMetadata(uint256 index) external onlyOwnerOrEditor {
        require(index < proposals.length, "Index out of bounds");
        address removed = address(proposals[index]);
        proposals[index] = proposals[proposals.length - 1];
        proposals.pop();
        emit ProposalRemoved(removed);
    }

    function getProposalsCount() external view returns (uint256) {
        return proposals.length;
    }

    function getProposals(uint256 offset, uint256 limit) external view returns (FutarchyProposalMetadata[] memory) {
        uint256 total = proposals.length;
        if (offset >= total) {
            return new FutarchyProposalMetadata[](0);
        }

        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }

        uint256 size = end - offset;
        FutarchyProposalMetadata[] memory result = new FutarchyProposalMetadata[](size);

        for (uint256 i = 0; i < size; i++) {
            result[i] = proposals[offset + i];
        }

        return result;
    }

    function _initializeOrganization(
        address owner_,
        string memory companyName_,
        string memory description_,
        string memory metadata_,
        string memory metadataURI_,
        address proposalImplementation_
    ) internal {
        _transferOwnership(owner_);
        companyName = companyName_;
        description = description_;
        metadata = metadata_;
        metadataURI = metadataURI_;
        proposalImplementation = proposalImplementation_;
        emit ProposalImplementationSet(proposalImplementation_);
    }

    function _setDefaultLiquidityManager(
        address defaultLiquidityManager_,
        address defaultProposalSource_,
        string memory liquidityManagerMetadataURI_
    ) internal {
        require(defaultLiquidityManager_ != address(0), "FLM not set");
        require(defaultProposalSource_ != address(0), "Proposal source not set");
        defaultLiquidityManager = defaultLiquidityManager_;
        defaultProposalSource = defaultProposalSource_;
        liquidityManagerMetadataURI = liquidityManagerMetadataURI_;
        emit DefaultLiquidityManagerSet(defaultLiquidityManager_, defaultProposalSource_, liquidityManagerMetadataURI_);
    }
}
