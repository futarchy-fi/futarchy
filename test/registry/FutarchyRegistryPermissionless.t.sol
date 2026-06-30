// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";

import { FutarchyAggregatorFactory } from "../../src/registry/FutarchyAggregatorFactory.sol";
import { FutarchyAggregatorsMetadata } from "../../src/registry/FutarchyAggregatorsMetadata.sol";
import { FutarchyOrganizationMetadata } from "../../src/registry/FutarchyOrganizationMetadata.sol";
import { OrganizationMetadataFactory } from "../../src/registry/OrganizationMetadataFactory.sol";
import { FutarchyProposalMetadata } from "../../src/registry/FutarchyProposalMetadata.sol";
import { ProposalMetadataFactory } from "../../src/registry/ProposalMetadataFactory.sol";

contract FutarchyRegistryPermissionlessTest is Test {
    FutarchyProposalMetadata internal proposalImplementation;
    FutarchyOrganizationMetadata internal organizationImplementation;
    FutarchyAggregatorsMetadata internal aggregatorImplementation;
    ProposalMetadataFactory internal proposalFactory;
    OrganizationMetadataFactory internal organizationFactory;
    FutarchyAggregatorFactory internal aggregatorFactory;

    address internal owner = makeAddr("owner");
    address internal orgCreator = makeAddr("orgCreator");
    address internal other = makeAddr("other");
    address internal editor = makeAddr("editor");
    address internal flm = makeAddr("flm");
    address internal proposalSource = makeAddr("proposalSource");

    function setUp() public {
        proposalImplementation = new FutarchyProposalMetadata();
        organizationImplementation = new FutarchyOrganizationMetadata();
        aggregatorImplementation = new FutarchyAggregatorsMetadata();

        proposalFactory = new ProposalMetadataFactory(address(proposalImplementation));
        organizationFactory =
            new OrganizationMetadataFactory(address(organizationImplementation), address(proposalImplementation));
        aggregatorFactory = new FutarchyAggregatorFactory(
            address(aggregatorImplementation), address(organizationImplementation), address(proposalImplementation)
        );
    }

    function testStandaloneFactoriesCreateOwnedMetadata() public {
        vm.prank(orgCreator);
        address proposal = proposalFactory.createProposalMetadata(
            orgCreator,
            "Will GIP-151 pass?",
            "GIP-151",
            "Gnosis proposal",
            '{"proposalCode":"GIP-151"}',
            "ipfs://gip151"
        );

        FutarchyProposalMetadata proposalMetadata = FutarchyProposalMetadata(proposal);
        assertEq(proposalMetadata.owner(), orgCreator);
        assertEq(proposalMetadata.proposalAddress(), orgCreator);
        assertEq(proposalMetadata.displayNameEvent(), "GIP-151");
        assertEq(proposalMetadata.metadataURI(), "ipfs://gip151");

        vm.prank(orgCreator);
        address organization = organizationFactory.createOrganizationMetadata(
            "Gnosis DAO", "Gnosis futarchy organization", '{"token":"GNO"}', "ipfs://gnosis"
        );

        FutarchyOrganizationMetadata organizationMetadata = FutarchyOrganizationMetadata(organization);
        assertEq(organizationMetadata.owner(), orgCreator);
        assertEq(organizationMetadata.companyName(), "Gnosis DAO");
        assertEq(organizationMetadata.proposalImplementation(), address(proposalImplementation));
    }

    function testAnyWalletCreatesOrganizationAndAggregatorListsIt() public {
        FutarchyAggregatorsMetadata aggregator = _createAggregator();

        vm.prank(orgCreator);
        address first = aggregator.createAndAddOrganizationMetadata(
            "Kleros DAO", "Kleros futarchy organization", '{"token":"PNK"}', "ipfs://kleros"
        );

        FutarchyOrganizationMetadata firstOrg = FutarchyOrganizationMetadata(first);
        FutarchyOrganizationMetadata[] memory organizations = aggregator.getOrganizations(0, 10);
        assertEq(firstOrg.owner(), orgCreator);
        assertEq(firstOrg.companyName(), "Kleros DAO");
        assertEq(aggregator.getOrganizationsCount(), 1);
        assertEq(address(organizations[0]), first);

        vm.prank(other);
        address second = aggregator.createAndAddOrganizationMetadata(
            "Gnosis DAO", "Gnosis futarchy organization", '{"token":"GNO"}', "ipfs://gnosis"
        );

        FutarchyOrganizationMetadata[] memory listed = aggregator.getOrganizations(0, 10);
        assertEq(FutarchyOrganizationMetadata(second).owner(), other);
        assertEq(aggregator.getOrganizationsCount(), 2);
        assertEq(address(listed[1]), second);
    }

    function testOrganizationCreatedWithDefaultFlmWiringIsListed() public {
        FutarchyAggregatorsMetadata aggregator = _createAggregator();

        vm.prank(orgCreator);
        address organization = aggregator.createAndAddOrganizationMetadataWithDefaultLiquidityManager(
            "Kleros DAO",
            "Kleros futarchy organization",
            '{"token":"PNK"}',
            "ipfs://kleros",
            flm,
            proposalSource,
            "ipfs://kleros-flm"
        );

        FutarchyOrganizationMetadata orgMetadata = FutarchyOrganizationMetadata(organization);
        assertEq(orgMetadata.owner(), orgCreator);
        assertEq(orgMetadata.defaultLiquidityManager(), flm);
        assertEq(orgMetadata.defaultProposalSource(), proposalSource);
        assertEq(orgMetadata.liquidityManagerMetadataURI(), "ipfs://kleros-flm");
        assertEq(aggregator.getOrganizationsCount(), 1);
        assertEq(address(aggregator.getOrganizations(0, 1)[0]), organization);
    }

    function testOnlyOrganizationOwnerOrEditorCreatesListedProposal() public {
        FutarchyAggregatorsMetadata aggregator = _createAggregator();

        vm.prank(orgCreator);
        FutarchyOrganizationMetadata organization = FutarchyOrganizationMetadata(
            aggregator.createAndAddOrganizationMetadata(
                "Kleros DAO", "Kleros futarchy organization", '{"token":"PNK"}', "ipfs://kleros"
            )
        );

        vm.expectRevert(bytes("Not owner or editor"));
        vm.prank(other);
        organization.createAndAddProposalMetadata(
            other, "Will KIP-90 pass?", "KIP-90", "Kleros proposal", '{"proposalCode":"KIP-90"}', "ipfs://kip90"
        );

        vm.prank(orgCreator);
        address firstProposal = organization.createAndAddProposalMetadata(
            orgCreator, "Will KIP-90 pass?", "KIP-90", "Kleros proposal", '{"proposalCode":"KIP-90"}', "ipfs://kip90"
        );

        assertEq(FutarchyProposalMetadata(firstProposal).owner(), orgCreator);
        assertEq(FutarchyProposalMetadata(firstProposal).proposalAddress(), orgCreator);
        assertEq(organization.getProposalsCount(), 1);
        assertEq(address(organization.getProposals(0, 1)[0]), firstProposal);

        vm.prank(orgCreator);
        organization.setEditor(editor);

        vm.prank(editor);
        address secondProposal = organization.createAndAddProposalMetadata(
            editor,
            "Will KIP-91 pass?",
            "KIP-91",
            "Editor-created Kleros proposal",
            '{"proposalCode":"KIP-91"}',
            "ipfs://kip91"
        );

        assertEq(FutarchyProposalMetadata(secondProposal).owner(), editor);
        assertEq(organization.getProposalsCount(), 2);
    }

    function testOnlyOrganizationOwnerOrEditorUpdatesFlmDefaults() public {
        FutarchyAggregatorsMetadata aggregator = _createAggregator();

        vm.prank(orgCreator);
        FutarchyOrganizationMetadata organization = FutarchyOrganizationMetadata(
            aggregator.createAndAddOrganizationMetadata(
                "Kleros DAO", "Kleros futarchy organization", '{"token":"PNK"}', "ipfs://kleros"
            )
        );

        vm.expectRevert(bytes("Not owner or editor"));
        vm.prank(other);
        organization.setDefaultLiquidityManager(flm, proposalSource, "ipfs://unauthorized");

        vm.prank(orgCreator);
        organization.setDefaultLiquidityManager(flm, proposalSource, "ipfs://owner-flm");

        assertEq(organization.defaultLiquidityManager(), flm);
        assertEq(organization.defaultProposalSource(), proposalSource);
        assertEq(organization.liquidityManagerMetadataURI(), "ipfs://owner-flm");
    }

    function _createAggregator() internal returns (FutarchyAggregatorsMetadata aggregator) {
        vm.prank(owner);
        address aggregatorAddress = aggregatorFactory.createAggregatorMetadata(
            "Permissionless Futarchy",
            "Permissionless Gnosis testnet aggregator",
            '{"chainId":10200,"mode":"permissionless"}',
            "ipfs://aggregator"
        );
        aggregator = FutarchyAggregatorsMetadata(aggregatorAddress);
        assertEq(aggregator.owner(), owner);
        assertEq(aggregator.organizationImplementation(), address(organizationImplementation));
        assertEq(aggregator.proposalImplementation(), address(proposalImplementation));
    }
}
