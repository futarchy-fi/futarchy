// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/liquidity/V2PoolDeploymentEngine.sol";
import "../src/liquidity/LiquidityCalculationEngine.sol";
import "../src/interfaces/ISushiswapV2Factory.sol";
import "../src/interfaces/ISushiswapV2Router.sol";
import "../src/interfaces/IERC20Extended.sol";

contract V2PoolDeploymentEngineTest is Test {
    // Contracts
    V2PoolDeploymentEngine public engine;
    
    // Mocked contract addresses
    address public mockFactory;
    address public mockRouter;
    address public mockWxdai;
    address public mockToken1;
    address public mockToken2;
    
    // Pool parameters
    LiquidityCalculationEngine.PoolLiquidity[] public pools;

    function setUp() public {
        // Create mock addresses for testing
        mockFactory = makeAddr("SushiswapV2Factory");
        mockRouter = makeAddr("SushiswapV2Router"); 
        mockWxdai = makeAddr("WXDAI");
        mockToken1 = makeAddr("YesToken");
        mockToken2 = makeAddr("NoToken");
        
        // Deploy the engine with mock addresses
        engine = new V2PoolDeploymentEngine(mockFactory, mockRouter, mockWxdai);
        
        // Create mock pool configuration
        LiquidityCalculationEngine.PoolLiquidity memory pool1 = LiquidityCalculationEngine.PoolLiquidity({
            token0: mockWxdai,
            token1: mockToken1,
            amount0: 10e18,
            amount1: 20e18,
            initialPrice: 0.5e18,
            isV3: false,
            tickLower: 0,
            tickUpper: 0,
            fee: 0
        });
        
        pools.push(pool1);
    }
    
    function testConstructor() public {
        assertEq(address(engine.sushiV2Factory()), mockFactory, "Factory address mismatch");
        assertEq(address(engine.sushiV2Router()), mockRouter, "Router address mismatch");
        assertEq(engine.wxdai(), mockWxdai, "WXDAI address mismatch");
    }
    
    function testPairExists() public {
        // Mock factory response for getPair
        vm.mockCall(
            mockFactory,
            abi.encodeWithSelector(ISushiswapV2Factory.getPair.selector, mockWxdai, mockToken1),
            abi.encode(address(0))
        );
        
        address pair = engine.pairExists(mockWxdai, mockToken1);
        assertEq(pair, address(0), "Pair should not exist");
        
        // Change mock to return a pair address
        address mockPairAddress = makeAddr("PairAddress");
        vm.mockCall(
            mockFactory,
            abi.encodeWithSelector(ISushiswapV2Factory.getPair.selector, mockWxdai, mockToken1),
            abi.encode(mockPairAddress)
        );
        
        pair = engine.pairExists(mockWxdai, mockToken1);
        assertEq(pair, mockPairAddress, "Pair should exist");
    }
    
    function testCreatePairIfNeeded_ExistingPair() public {
        // Mock that pair already exists
        address mockPairAddress = makeAddr("PairAddress");
        vm.mockCall(
            mockFactory,
            abi.encodeWithSelector(ISushiswapV2Factory.getPair.selector, mockWxdai, mockToken1),
            abi.encode(mockPairAddress)
        );
        
        address pair = engine.createPairIfNeeded(mockWxdai, mockToken1);
        assertEq(pair, mockPairAddress, "Should return existing pair");
    }
    
    function testCreatePairIfNeeded_NewPair() public {
        // Mock that pair doesn't exist yet
        vm.mockCall(
            mockFactory,
            abi.encodeWithSelector(ISushiswapV2Factory.getPair.selector, mockWxdai, mockToken1),
            abi.encode(address(0))
        );
        
        // Mock pair creation
        address mockPairAddress = makeAddr("NewPairAddress");
        vm.mockCall(
            mockFactory,
            abi.encodeWithSelector(ISushiswapV2Factory.createPair.selector, mockWxdai, mockToken1),
            abi.encode(mockPairAddress)
        );
        
        address pair = engine.createPairIfNeeded(mockWxdai, mockToken1);
        assertEq(pair, mockPairAddress, "Should return newly created pair");
    }
    
    function testEnsureTokenApproval() public {
        // First scenario: no allowance, expect approve to be called
        
        // Mock token allowance check - no allowance
        vm.mockCall(
            mockToken1,
            abi.encodeWithSelector(IERC20.allowance.selector, address(engine), mockRouter),
            abi.encode(0)
        );
        
        // Mock approve call
        vm.mockCall(
            mockToken1,
            abi.encodeWithSelector(IERC20.approve.selector, mockRouter, type(uint256).max),
            abi.encode(true)
        );
        
        // We expect the approve function to be called
        vm.expectCall(
            mockToken1,
            abi.encodeWithSelector(IERC20.approve.selector, mockRouter, type(uint256).max)
        );
        
        engine.ensureTokenApproval(mockToken1, 1e18);
    }
    
    function testEnsureTokenApproval_SufficientAllowance() public {
        // Second scenario: sufficient allowance, expect approve NOT to be called
        
        // Mock that we already have enough allowance
        vm.mockCall(
            mockToken1,
            abi.encodeWithSelector(IERC20.allowance.selector, address(engine), mockRouter),
            abi.encode(2e18)
        );
        
        // Call the function (we're not setting any expectation, so this should pass)
        engine.ensureTokenApproval(mockToken1, 1e18);
        
        // The test passes if we get here without an approve call being made
    }
    
    function testAddLiquidity() public {
        // Mock token approvals
        vm.mockCall(
            mockWxdai,
            abi.encodeWithSelector(IERC20.allowance.selector, address(engine), mockRouter),
            abi.encode(type(uint256).max)
        );
        
        vm.mockCall(
            mockToken1,
            abi.encodeWithSelector(IERC20.allowance.selector, address(engine), mockRouter),
            abi.encode(type(uint256).max)
        );
        
        // Mock addLiquidity call
        uint256 returnAmountA = 9.9e18;
        uint256 returnAmountB = 19.8e18;
        uint256 returnLiquidity = 14e18;
        vm.mockCall(
            mockRouter,
            abi.encodeWithSelector(
                ISushiswapV2Router.addLiquidity.selector,
                mockWxdai,
                mockToken1,
                10e18,
                20e18,
                10e18 * 99 / 100,
                20e18 * 99 / 100,
                address(engine),
                block.timestamp + 1800
            ),
            abi.encode(returnAmountA, returnAmountB, returnLiquidity)
        );
        
        // Mock getPair call
        address mockPairAddress = makeAddr("PairAddress");
        vm.mockCall(
            mockFactory,
            abi.encodeWithSelector(ISushiswapV2Factory.getPair.selector, mockWxdai, mockToken1),
            abi.encode(mockPairAddress)
        );
        
        // Call addLiquidity
        (uint256 amountA, uint256 amountB, uint256 liquidity) = engine.addLiquidity(pools[0]);
        
        // Verify results
        assertEq(amountA, returnAmountA, "AmountA mismatch");
        assertEq(amountB, returnAmountB, "AmountB mismatch");
        assertEq(liquidity, returnLiquidity, "Liquidity mismatch");
    }
    
    function testDeployPool() public {
        // Mock pair exists call
        vm.mockCall(
            mockFactory,
            abi.encodeWithSelector(ISushiswapV2Factory.getPair.selector, mockWxdai, mockToken1),
            abi.encode(address(0))
        );
        
        // Mock create pair call
        address mockPairAddress = makeAddr("NewPairAddress");
        vm.mockCall(
            mockFactory,
            abi.encodeWithSelector(ISushiswapV2Factory.createPair.selector, mockWxdai, mockToken1),
            abi.encode(mockPairAddress)
        );
        
        // Mock token approvals
        vm.mockCall(
            mockWxdai,
            abi.encodeWithSelector(IERC20.allowance.selector, address(engine), mockRouter),
            abi.encode(type(uint256).max)
        );
        
        vm.mockCall(
            mockToken1,
            abi.encodeWithSelector(IERC20.allowance.selector, address(engine), mockRouter),
            abi.encode(type(uint256).max)
        );
        
        // Mock addLiquidity call
        uint256 returnLiquidity = 14e18;
        vm.mockCall(
            mockRouter,
            abi.encodeWithSelector(
                ISushiswapV2Router.addLiquidity.selector,
                mockWxdai,
                mockToken1,
                10e18,
                20e18,
                10e18 * 99 / 100,
                20e18 * 99 / 100,
                address(engine),
                block.timestamp + 1800
            ),
            abi.encode(9.9e18, 19.8e18, returnLiquidity)
        );
        
        // Call deployPool
        (address pair, uint256 liquidity) = engine.deployPool(pools[0]);
        
        // Verify results
        assertEq(pair, mockPairAddress, "Pair address mismatch");
        assertEq(liquidity, returnLiquidity, "Liquidity mismatch");
    }
    
    function testSkipV3Pool() public {
        // Create a V3 pool
        LiquidityCalculationEngine.PoolLiquidity memory v3Pool = LiquidityCalculationEngine.PoolLiquidity({
            token0: mockWxdai,
            token1: mockToken1,
            amount0: 10e18,
            amount1: 20e18,
            initialPrice: 0.5e18,
            isV3: true,
            tickLower: -1000,
            tickUpper: 1000,
            fee: 3000
        });
        
        // Call deployPool with V3 pool
        (address pair, uint256 liquidity) = engine.deployPool(v3Pool);
        
        // Verify it was skipped
        assertEq(pair, address(0), "Should return zero address for V3 pool");
        assertEq(liquidity, 0, "Should return zero liquidity for V3 pool");
    }
} 