// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import { FutarchyOrganizationMetadata } from "./FutarchyOrganizationMetadata.sol";

contract FutarchyAggregatorsMetadata is Ownable, Initializable {
    string public aggregatorName;
    string public description;
    string public metadata;
    string public metadataURI;
    FutarchyOrganizationMetadata[] public organizations;

    address public editor;
    address public organizationImplementation;
    address public proposalImplementation;

    event AggregatorInfoUpdated(string newName, string newDescription);
    event ExtendedMetadataUpdated(string metadata, string metadataURI);
    event OrganizationAdded(address indexed organizationMetadata);
    event OrganizationRemoved(address indexed organizationMetadata);
    event OrganizationCreatedAndAdded(address indexed organizationMetadata, string companyName);
    event EditorSet(address indexed newEditor);
    event EditorRevoked(address indexed oldEditor);
    event OrganizationImplementationSet(address indexed implementation);
    event ProposalImplementationSet(address indexed implementation);

    modifier onlyOwnerOrEditor() {
        require(msg.sender == owner() || msg.sender == editor, "Not owner or editor");
        _;
    }

    constructor() Ownable(msg.sender) {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        string memory aggregatorName_,
        string memory description_,
        string memory metadata_,
        string memory metadataURI_,
        address organizationImplementation_,
        address proposalImplementation_
    ) external initializer {
        _transferOwnership(owner_);
        aggregatorName = aggregatorName_;
        description = description_;
        metadata = metadata_;
        metadataURI = metadataURI_;
        organizationImplementation = organizationImplementation_;
        proposalImplementation = proposalImplementation_;
        emit OrganizationImplementationSet(organizationImplementation_);
        emit ProposalImplementationSet(proposalImplementation_);
    }

    function setOrganizationImplementation(address implementation) external onlyOwner {
        organizationImplementation = implementation;
        emit OrganizationImplementationSet(implementation);
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

    function updateAggregatorInfo(string memory newName, string memory newDescription) external onlyOwnerOrEditor {
        aggregatorName = newName;
        description = newDescription;
        emit AggregatorInfoUpdated(newName, newDescription);
    }

    function updateExtendedMetadata(string memory metadata_, string memory metadataURI_) external onlyOwnerOrEditor {
        metadata = metadata_;
        metadataURI = metadataURI_;
        emit ExtendedMetadataUpdated(metadata_, metadataURI_);
    }

    function addOrganizationMetadata(address organizationMetadata) external onlyOwnerOrEditor {
        organizations.push(FutarchyOrganizationMetadata(organizationMetadata));
        emit OrganizationAdded(organizationMetadata);
    }

    function createAndAddOrganizationMetadata(
        string memory companyName,
        string memory description_,
        string memory metadata_,
        string memory metadataURI_
    ) external returns (address) {
        require(organizationImplementation != address(0), "Organization implementation not set");

        address clone = Clones.clone(organizationImplementation);
        FutarchyOrganizationMetadata(clone)
            .initialize(msg.sender, companyName, description_, metadata_, metadataURI_, proposalImplementation);

        organizations.push(FutarchyOrganizationMetadata(clone));
        emit OrganizationCreatedAndAdded(clone, companyName);
        return clone;
    }

    function createAndAddOrganizationMetadataWithDefaultLiquidityManager(
        string memory companyName,
        string memory description_,
        string memory metadata_,
        string memory metadataURI_,
        address defaultLiquidityManager,
        address defaultProposalSource,
        string memory liquidityManagerMetadataURI
    ) external returns (address) {
        require(organizationImplementation != address(0), "Organization implementation not set");

        address clone = Clones.clone(organizationImplementation);
        FutarchyOrganizationMetadata(clone)
            .initializeWithDefaultLiquidityManager(
                msg.sender,
                companyName,
                description_,
                metadata_,
                metadataURI_,
                proposalImplementation,
                defaultLiquidityManager,
                defaultProposalSource,
                liquidityManagerMetadataURI
            );

        organizations.push(FutarchyOrganizationMetadata(clone));
        emit OrganizationCreatedAndAdded(clone, companyName);
        return clone;
    }

    function removeOrganizationMetadata(uint256 index) external onlyOwnerOrEditor {
        require(index < organizations.length, "Index out of bounds");
        address removed = address(organizations[index]);
        organizations[index] = organizations[organizations.length - 1];
        organizations.pop();
        emit OrganizationRemoved(removed);
    }

    function getOrganizationsCount() external view returns (uint256) {
        return organizations.length;
    }

    function getOrganizations(uint256 offset, uint256 limit)
        external
        view
        returns (FutarchyOrganizationMetadata[] memory)
    {
        uint256 total = organizations.length;
        if (offset >= total) {
            return new FutarchyOrganizationMetadata[](0);
        }

        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }

        uint256 size = end - offset;
        FutarchyOrganizationMetadata[] memory result = new FutarchyOrganizationMetadata[](size);

        for (uint256 i = 0; i < size; i++) {
            result[i] = organizations[offset + i];
        }

        return result;
    }
}
