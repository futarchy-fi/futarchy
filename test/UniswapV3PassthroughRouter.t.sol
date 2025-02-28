// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/UniswapV3PassthroughRouter.sol";
import "../src/interfaces/IUniswapV3Pool.sol";
import "../src/interfaces/IERC20Minimal.sol";

// Mock UniswapV3Pool for testing
contract MockUniswapV3Pool is IUniswapV3Pool {
    address public override token0;
    address public override token1;
    address private owner;
    
    // Callback interface for swap
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        // This function is required in the real pool
        // In the test, we'll check if this is called correctly
    }

    // Constructor to set tokens for the mock pool
    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
        owner = msg.sender;
    }
    
    // Mock implementation of swap that records inputs and calls callback
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external override returns (int256 amount0, int256 amount1) {
        // Record swap information for testing
        
        // Prepare callback data
        if (zeroForOne) {
            amount0 = amountSpecified;
            amount1 = -amountSpecified / 2; // Mock exchange rate
            
            // Call the callback to request tokens
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(
                amount0, // Positive means we need tokens
                0,       // No token1 needed
                data     // Pass through the data
            );
        } else {
            amount0 = -amountSpecified / 2; // Mock exchange rate
            amount1 = amountSpecified;
            
            // Call the callback to request tokens
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(
                0,       // No token0 needed
                amount1, // Positive means we need tokens
                data     // Pass through the data
            );
        }
        
        return (amount0, amount1);
    }
    
    // Stub implementations for required interface methods
    function observe(uint32[] calldata)
        external
        pure
        override
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) {
        // Return dummy values
        tickCumulatives = new int56[](1);
        secondsPerLiquidityCumulativeX128s = new uint160[](1);
    }
    
    function liquidity() external pure override returns (uint128) {
        return 1000000; // Return a dummy value
    }
}

// Mock ERC20 token for testing
contract MockERC20 is IERC20Minimal {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }
    
    function mint(address account, uint256 amount) external {
        _balances[account] += amount;
        _totalSupply += amount;
    }
    
    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }
    
    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        _transfer(sender, recipient, amount);
        
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, msg.sender, currentAllowance - amount);
        
        return true;
    }
    
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        
        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        _balances[sender] = senderBalance - amount;
        _balances[recipient] += amount;
    }
    
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        
        _allowances[owner][spender] = amount;
    }
}

contract UniswapV3PassthroughRouterTest is Test {
    // Contract instances
    UniswapV3PassthroughRouter public router;
    MockUniswapV3Pool public pool;
    MockERC20 public token0;
    MockERC20 public token1;
    address public user;
    
    // Set up the test
    function setUp() public {
        // Create a test user
        user = makeAddr("user");
        vm.deal(user, 100 ether);
        
        // Deploy mock tokens
        token0 = new MockERC20("Token0", "TKN0");
        token1 = new MockERC20("Token1", "TKN1");
        
        // Sort tokens to match Uniswap's convention
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }
        
        // Create a mock pool
        pool = new MockUniswapV3Pool(address(token0), address(token1));
        
        // Deploy the router
        router = new UniswapV3PassthroughRouter();
        
        // Mint tokens to the user
        token0.mint(user, 1000 ether);
        token1.mint(user, 1000 ether);
    }
    
    // Test swap token0 for token1
    function testSwapExactInput() public {
        // Set up user context
        vm.startPrank(user);
        
        // Approve router to spend user's tokens
        token0.approve(address(router), 10 ether);
        
        // Prepare swap parameters
        address recipient = user;
        bool zeroForOne = true;
        int256 amountSpecified = 10 ether; // Exact input
        uint160 sqrtPriceLimitX96 = 0; // No price limit
        bytes memory data = "";
        
        // Perform the swap
        (int256 amount0, int256 amount1) = router.swap(
            address(pool),
            recipient,
            zeroForOne,
            amountSpecified,
            sqrtPriceLimitX96,
            data
        );
        
        // Check results
        assertEq(amount0, 10 ether, "Incorrect amount0 returned");
        assertEq(amount1, -5 ether, "Incorrect amount1 returned"); // Based on mock rate
        
        vm.stopPrank();
    }
} 