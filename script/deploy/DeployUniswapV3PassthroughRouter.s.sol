// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/UniswapV3PassthroughRouter.sol";

contract DeployUniswapV3PassthroughRouter is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the router
        UniswapV3PassthroughRouter router = new UniswapV3PassthroughRouter();
        
        console.log("UniswapV3PassthroughRouter deployed to:", address(router));
        
        vm.stopBroadcast();
    }
} 