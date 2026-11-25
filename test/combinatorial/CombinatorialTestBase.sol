// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/combinatorial/CanonicalFormLib.sol";
import "../../src/combinatorial/ExpressionEvaluatorLib.sol";
import "../../src/combinatorial/EventContract.sol";
import "../../src/combinatorial/ExpressionContract.sol";
import "../../src/combinatorial/PositionTokenContract.sol";

contract MockCollateral is ERC20 {
    constructor() ERC20("Mock Dollar", "MUSD") { }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev Burns 1% of every transfer between two accounts
contract FeeCollateral is ERC20 {
    constructor() ERC20("Fee Dollar", "FUSD") { }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from == address(0) || to == address(0)) {
            super._update(from, to, value);
            return;
        }
        uint256 fee = value / 100;
        super._update(from, to, value - fee);
        super._update(from, address(0), fee);
    }
}

/// @dev Exposes the internal library functions
contract LibHarness {
    function canonicalizeConjunction(uint256[] memory literals) external pure returns (uint256[] memory, bool) {
        return CanonicalFormLib.canonicalizeConjunction(literals);
    }

    function canonicalizeExpression(uint256[][] memory conjunctions) external pure returns (uint256[][] memory) {
        return CanonicalFormLib.canonicalizeExpression(conjunctions);
    }

    function areConjunctionsExclusive(uint256[] memory a, uint256[] memory b) external pure returns (bool) {
        return CanonicalFormLib.areConjunctionsExclusive(a, b);
    }

    function hash(uint256[][] memory conjunctions) external pure returns (bytes32) {
        return CanonicalFormLib.computeExpressionHash(conjunctions);
    }

    function evaluate(uint256[][] memory conjunctions, uint256[] memory ids, uint256[] memory values)
        external
        pure
        returns (uint256)
    {
        return ExpressionEvaluatorLib.evaluateExpressionWithValues(conjunctions, ids, values);
    }
}

abstract contract CombinatorialTestBase is Test {
    uint256 internal constant SCALE = 1e18;
    uint256 internal constant NEG = 1 << 255;

    EventContract internal events;
    ExpressionContract internal expr;
    PositionTokenContract internal pt;
    MockCollateral internal usd;
    LibHarness internal lib;

    address internal oracle = makeAddr("oracle");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    uint256 internal X;
    uint256 internal Y;
    uint256 internal Z;

    function setUp() public virtual {
        events = new EventContract();
        expr = new ExpressionContract();
        pt = new PositionTokenContract(address(expr), address(events), "");
        usd = new MockCollateral();
        lib = new LibHarness();

        X = events.createEvent(oracle, bytes32("X"));
        Y = events.createEvent(oracle, bytes32("Y"));
        Z = events.createEvent(oracle, bytes32("Z"));
    }

    function _pid(uint256 expressionId) internal view returns (uint256) {
        return pt.getPositionId(usd, expressionId);
    }

    function _bal(address who, uint256 expressionId) internal view returns (uint256) {
        return pt.balanceOf(who, _pid(expressionId));
    }

    function _deposit(address who, uint256 amount) internal {
        usd.mint(who, amount);
        vm.startPrank(who);
        usd.approve(address(pt), amount);
        pt.createPosition(usd, amount);
        vm.stopPrank();
    }

    /// @dev Partitions `who`'s whole balance of the position on `expressionId`; returns the two new expression ids
    function _partition(address who, uint256 expressionId, uint256 variable)
        internal
        returns (uint256 withVar, uint256 withNotVar)
    {
        uint256 positionId = _pid(expressionId);
        vm.prank(who);
        pt.partitionPosition(positionId, variable);
        (withVar, withNotVar) = expr.splitExpression(expressionId, variable);
    }

    function _mergeOnVariable(address who, uint256 exprWithVar, uint256 exprWithNotVar, uint256 variable)
        internal
        returns (uint256 merged)
    {
        uint256 positionWithVar = _pid(exprWithVar);
        uint256 positionWithNotVar = _pid(exprWithNotVar);
        vm.prank(who);
        pt.mergePositionsOnVariable(positionWithVar, positionWithNotVar, variable);
        merged = expr.mergeExpressionsOnVariable(exprWithVar, exprWithNotVar, variable);
    }

    function _settle(uint256 eventId, uint256 outcome) internal {
        vm.prank(oracle);
        events.settleEvent(eventId, outcome);
    }

    function _redeemAll(address who, uint256 expressionId) internal returns (uint256 payout) {
        uint256 balance = _bal(who, expressionId);
        if (balance == 0) return 0;
        uint256 before = usd.balanceOf(who);
        uint256 positionId = _pid(expressionId);
        vm.prank(who);
        pt.redeemPosition(positionId, balance);
        payout = usd.balanceOf(who) - before;
    }

    function _merge(address who, uint256 exprId1, uint256 exprId2) internal returns (uint256 merged) {
        uint256 positionId1 = _pid(exprId1);
        uint256 positionId2 = _pid(exprId2);
        vm.prank(who);
        pt.mergePositions(positionId1, positionId2);
        merged = expr.mergeExpressions(exprId1, exprId2);
    }

    function _partialEvaluate(address who, uint256 expressionId, uint256 variable) internal {
        uint256 positionId = _pid(expressionId);
        vm.prank(who);
        pt.partialEvaluatePosition(positionId, variable);
    }

    function _ids(uint256 a, uint256 b) internal pure returns (uint256[] memory out) {
        out = new uint256[](2);
        out[0] = a;
        out[1] = b;
    }
}
