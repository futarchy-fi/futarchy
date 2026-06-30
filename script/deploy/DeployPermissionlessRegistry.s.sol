// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console2 } from "forge-std/Script.sol";

import { FutarchyAggregatorFactory } from "../../src/registry/FutarchyAggregatorFactory.sol";
import { FutarchyAggregatorsMetadata } from "../../src/registry/FutarchyAggregatorsMetadata.sol";
import { FutarchyOrganizationMetadata } from "../../src/registry/FutarchyOrganizationMetadata.sol";
import { FutarchyProposalMetadata } from "../../src/registry/FutarchyProposalMetadata.sol";
import { OrganizationMetadataFactory } from "../../src/registry/OrganizationMetadataFactory.sol";
import { ProposalMetadataFactory } from "../../src/registry/ProposalMetadataFactory.sol";

contract DeployPermissionlessRegistry is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        string memory aggregatorName = vm.envOr("REGISTRY_AGGREGATOR_NAME", string("Permissionless Futarchy"));
        string memory description = vm.envOr(
            "REGISTRY_AGGREGATOR_DESCRIPTION",
            string("Permissionless Futarchy organizations and proposals on Gnosis Chiado")
        );
        string memory metadata =
            vm.envOr("REGISTRY_AGGREGATOR_METADATA", string('{"chainId":10200,"mode":"permissionless"}'));
        string memory metadataURI = vm.envOr("REGISTRY_AGGREGATOR_METADATA_URI", string(""));

        vm.startBroadcast(privateKey);

        FutarchyProposalMetadata proposalImplementation = new FutarchyProposalMetadata();
        FutarchyOrganizationMetadata organizationImplementation = new FutarchyOrganizationMetadata();
        FutarchyAggregatorsMetadata aggregatorImplementation = new FutarchyAggregatorsMetadata();

        ProposalMetadataFactory proposalFactory = new ProposalMetadataFactory(address(proposalImplementation));
        OrganizationMetadataFactory organizationFactory =
            new OrganizationMetadataFactory(address(organizationImplementation), address(proposalImplementation));
        FutarchyAggregatorFactory aggregatorFactory = new FutarchyAggregatorFactory(
            address(aggregatorImplementation), address(organizationImplementation), address(proposalImplementation)
        );

        address aggregator =
            aggregatorFactory.createAggregatorMetadata(aggregatorName, description, metadata, metadataURI);

        vm.stopBroadcast();

        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer/owner:", vm.addr(privateKey));
        console2.log("Proposal implementation:", address(proposalImplementation));
        console2.log("Organization implementation:", address(organizationImplementation));
        console2.log("Aggregator implementation:", address(aggregatorImplementation));
        console2.log("Proposal factory:", address(proposalFactory));
        console2.log("Organization factory:", address(organizationFactory));
        console2.log("Aggregator factory:", address(aggregatorFactory));
        console2.log("Permissionless aggregator:", aggregator);
    }
}
