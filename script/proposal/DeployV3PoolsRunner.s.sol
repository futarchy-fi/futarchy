// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "./DeployV3Pools.s.sol";

/**
 * @title DeployV3PoolsRunner
 * @notice Runner script for the DeployV3Pools script
 */
contract DeployV3PoolsRunner is Script {
    function run() public {
        DeployV3Pools deployV3Pools = new DeployV3Pools();
        
        // First call setUp to initialize configurations
        deployV3Pools.setUp();
        
        // Then call run to execute the deployment
        deployV3Pools.run();
    }
} 