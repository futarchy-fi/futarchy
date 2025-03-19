// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/interfaces/IUniswapV3PassthroughRouter.sol";
import "../../src/interfaces/IERC20Minimal.sol";

contract RecoverTokensScript is Script {
    function run() external {
        // Required parameters - load from environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address routerAddress = vm.envAddress("ROUTER_ADDRESS");
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");

        // Verify parameters are set
        require(routerAddress != address(0), "Router address not set");
        require(tokenAddress != address(0), "Token address not set");

        // Get router and token instances
        IUniswapV3PassthroughRouter router = IUniswapV3PassthroughRouter(routerAddress);
        IERC20Minimal token = IERC20Minimal(tokenAddress);
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Get owner of the router (tokens will be sent here)
        address owner = router.owner();
        console.log("Router owner:", owner);
        
        // Get token balance of the router
        uint256 balance = token.balanceOf(routerAddress);
        console.log("Router token balance:", balance);
        
        if (balance > 0) {
            // Prepare exec call data to transfer tokens from router to owner
            bytes memory transferData = abi.encodeWithSelector(
                IERC20Minimal.transfer.selector, 
                owner, 
                balance
            );
            
            // Prepare the multicall data - just one call to exec
            bytes[] memory multicallData = new bytes[](1);
            multicallData[0] = abi.encodeWithSelector(
                IUniswapV3PassthroughRouter.exec.selector,
                tokenAddress, // target (token contract)
                0,           // value (no ETH sent)
                transferData // data (transfer call)
            );
            
            // Execute the multicall
            console.log("Executing multicall to transfer tokens to owner...");
            router.multicall(multicallData);
            
            // Verify the transfer worked
            uint256 newBalance = token.balanceOf(routerAddress);
            console.log("Router token balance after transfer:", newBalance);
            console.log("Owner token balance:", token.balanceOf(owner));
        } else {
            console.log("No tokens to transfer");
        }
        
        vm.stopBroadcast();
    }
} 