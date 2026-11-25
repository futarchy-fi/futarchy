// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./CombinatorialTestBase.sol";

/// @notice One test (or a few) for each defect fixed in src/combinatorial
contract CombinatorialFixesTest is CombinatorialTestBase {
    // ---------------------------------------------------------------- 1. TRUE is not FALSE

    function test_TrueAndFalseAreDifferentExpressions() public view {
        assertEq(expr.getTrueExpressionId(), 1);
        assertEq(expr.getFalseExpressionId(), 2);
        assertTrue(expr.expressionExists(1));
        assertTrue(expr.expressionExists(2));

        uint256[][] memory trueForm = expr.getConjunctions(1);
        assertEq(trueForm.length, 1, "TRUE is one empty conjunction");
        assertEq(trueForm[0].length, 0);
        assertEq(expr.getConjunctions(2).length, 0, "FALSE has no conjunction");

        uint256[] memory none = new uint256[](0);
        assertEq(expr.evaluateExpressionWithValues(1, none, none), SCALE);
        assertEq(expr.evaluateExpressionWithValues(2, none, none), 0);
    }

    function test_DepositCanBeRedeemed() public {
        _deposit(alice, 100);
        assertEq(_bal(alice, 1), 100);

        (uint256 x, uint256 notX) = _partition(alice, 1, X);
        assertTrue(x != 1 && notX != 1 && x != notX, "partition of TRUE gives two new expressions");
        assertEq(_bal(alice, 1), 0);
        assertEq(_bal(alice, x), 100);
        assertEq(_bal(alice, notX), 100);

        _mergeOnVariable(alice, x, notX, X);
        assertEq(_redeemAll(alice, 1), 100);
        assertEq(usd.balanceOf(address(pt)), 0);
    }

    // ---------------------------------------------------------------- 2. merges move the minimum

    function test_MergeOnVariableDoesNotMintTheSum() public {
        _deposit(alice, 100);
        _deposit(bob, 100);

        (uint256 x, uint256 notX) = _partition(alice, 1, X);
        uint256 merged = _mergeOnVariable(alice, x, notX, X);
        assertEq(merged, 1);
        assertEq(_bal(alice, 1), 100, "100 in, 100 out");

        assertEq(_redeemAll(alice, 1), 100);
        assertEq(_redeemAll(bob, 1), 100, "bob's deposit is still there");
    }

    function test_MergeOnVariableWithUnequalBalancesLeavesTheRemainder() public {
        _deposit(alice, 100);
        (uint256 x, uint256 notX) = _partition(alice, 1, X);

        uint256 notXPosition = _pid(notX);
        vm.prank(alice);
        pt.safeTransferFrom(alice, bob, notXPosition, 60, "");

        _mergeOnVariable(alice, x, notX, X);
        assertEq(_bal(alice, 1), 40);
        assertEq(_bal(alice, x), 60);
        assertEq(_bal(alice, notX), 0);
    }

    function test_MergePositionsDoesNotMintTheSum() public {
        _deposit(alice, 100);
        _deposit(bob, 100);
        (uint256 x, uint256 notX) = _partition(alice, 1, X);

        uint256 either = _merge(alice, x, notX);
        assertEq(_bal(alice, either), 100);
        assertEq(_bal(alice, x), 0);
        assertEq(_bal(alice, notX), 0);

        _settle(X, SCALE);
        assertEq(_redeemAll(alice, either), 100);
        assertEq(_redeemAll(bob, 1), 100);
    }

    function test_MergeRejectsTheSamePositionTwice() public {
        _deposit(alice, 100);
        (uint256 x,) = _partition(alice, 1, X);
        uint256 xPosition = _pid(x);
        vm.startPrank(alice);
        vm.expectRevert(PositionTokenContract.SamePosition.selector);
        pt.mergePositions(xPosition, xPosition);
        vm.expectRevert(PositionTokenContract.SamePosition.selector);
        pt.mergePositionsOnVariable(xPosition, xPosition, X);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------- 3. partial evaluation reads the oracle

    function test_PartialEvaluateNeedsASettledEvent() public {
        _deposit(alice, 100);
        (uint256 x, uint256 notX) = _partition(alice, 1, X);

        uint256 xPosition = _pid(x);
        uint256 notXPosition = _pid(notX);
        vm.startPrank(alice);
        vm.expectRevert(PositionTokenContract.EventsNotSettled.selector);
        pt.partialEvaluatePosition(xPosition, X);
        vm.expectRevert(PositionTokenContract.EventsNotSettled.selector);
        pt.partialEvaluatePosition(notXPosition, X);
        vm.stopPrank();
    }

    function test_PartialEvaluateUsesTheSettledValue() public {
        _deposit(alice, 100);
        (uint256 x, uint256 notX) = _partition(alice, 1, X);
        _settle(X, SCALE / 4);

        _partialEvaluate(alice, x, X);
        _partialEvaluate(alice, notX, X);

        // X at 0.25: 100 X is worth 25, 100 not-X is worth 75
        assertEq(_bal(alice, 1), 100);
        assertEq(_bal(alice, 2), 100);
        assertEq(_redeemAll(alice, 1), 100);
        assertEq(_redeemAll(alice, 2), 0);
    }

    function test_PartialEvaluateRoundsDown() public {
        _deposit(alice, 3);
        (uint256 x,) = _partition(alice, 1, X);
        _settle(X, SCALE / 2);

        _partialEvaluate(alice, x, X);
        assertEq(_bal(alice, 1), 1, "3 * 0.5 rounds down to 1");
        assertEq(_bal(alice, 2), 1);
    }

    function test_PartialEvaluateOnAnUnrelatedVariableChangesNothing() public {
        _deposit(alice, 3);
        (uint256 x,) = _partition(alice, 1, X);
        _settle(Y, SCALE / 2);

        _partialEvaluate(alice, x, Y);
        assertEq(_bal(alice, x), 3, "X does not depend on Y");
    }

    // ---------------------------------------------------------------- 4. contradictions

    function test_ContradictionIsFoundWhereverItSits() public {
        uint256[] memory literals = new uint256[](3);
        literals[0] = 1;
        literals[1] = 2;
        literals[2] = 1 | NEG;
        (, bool isValid) = lib.canonicalizeConjunction(literals);
        assertFalse(isValid, "1 and 2 and not-1 is a contradiction");

        uint256 xAndY =
            expr.andExpressions(expr.createLiteralExpression(int256(X)), expr.createLiteralExpression(int256(Y)));
        (uint256 withX, uint256 withNotX) = expr.splitExpression(xAndY, X);
        assertEq(withX, xAndY);
        assertEq(withNotX, expr.getFalseExpressionId(), "X and Y and not-X is FALSE");
        assertEq(expr.andExpressions(xAndY, expr.createLiteralExpression(-int256(X))), expr.getFalseExpressionId());
    }

    function test_LiteralsSortByVariableThenSign() public view {
        uint256[] memory literals = new uint256[](4);
        literals[0] = 3 | NEG;
        literals[1] = 2;
        literals[2] = 1 | NEG;
        literals[3] = 2;
        (uint256[] memory clean, bool isValid) = lib.canonicalizeConjunction(literals);
        assertTrue(isValid);
        assertEq(clean.length, 3);
        assertEq(clean[0], 1 | NEG);
        assertEq(clean[1], 2);
        assertEq(clean[2], 3 | NEG);
    }

    // ---------------------------------------------------------------- 5. hash

    /// @dev The old hash was keccak(literals... ++ 0x00) per conjunction, built with abi.encodePacked
    function _oldPackedHash(uint256[][] memory conjunctions) internal pure returns (bytes32) {
        bytes memory data;
        for (uint256 i = 0; i < conjunctions.length; i++) {
            for (uint256 j = 0; j < conjunctions[i].length; j++) {
                data = abi.encodePacked(data, conjunctions[i][j]);
            }
            data = abi.encodePacked(data, bytes1(0x00));
        }
        return keccak256(data);
    }

    function test_HashSeparatesExpressionsThatThePackedHashConfused() public view {
        // 1089 bytes read two ways: 33 conjunctions of one literal (33 bytes each: a word and the 0x00
        // separator), or one conjunction of 34 literals (34 words and one separator).
        bytes memory stream = new bytes(33 * 33);
        for (uint256 i = 0; i < 33; i++) {
            stream[33 * i] = bytes1(uint8(i));
        }
        for (uint256 j = 2; j < 33; j++) {
            stream[32 * j] = bytes1(uint8(j - 1));
        }

        uint256[][] memory orOfLiterals = new uint256[][](33);
        for (uint256 i = 0; i < 33; i++) {
            orOfLiterals[i] = new uint256[](1);
            orOfLiterals[i][0] = _word(stream, 33 * i);
        }
        uint256[][] memory oneConjunction = new uint256[][](1);
        oneConjunction[0] = new uint256[](34);
        for (uint256 j = 0; j < 34; j++) {
            oneConjunction[0][j] = _word(stream, 32 * j);
        }

        assertEq(_oldPackedHash(orOfLiterals), _oldPackedHash(oneConjunction), "the packed hash collides");
        assertTrue(lib.hash(orOfLiterals) != lib.hash(oneConjunction), "the new hash does not");
    }

    function _word(bytes memory stream, uint256 offset) internal pure returns (uint256 word) {
        assembly {
            word := mload(add(add(stream, 32), offset))
        }
    }

    function test_HashCostIsLinear() public view {
        uint256[][] memory small = _manyConjunctions(128);
        uint256[][] memory large = _manyConjunctions(1024);

        uint256 gasBefore = gasleft();
        lib.hash(small);
        uint256 gasSmall = gasBefore - gasleft();

        gasBefore = gasleft();
        lib.hash(large);
        uint256 gasLarge = gasBefore - gasleft();

        // The packed hash cost 9.2M gas for 128 conjunctions of 2 literals and ran out of gas at 512
        assertLt(gasLarge, 5_000_000, "1024 conjunctions of 2 literals");
        assertLt(gasLarge, 12 * gasSmall, "8 times the size costs about 8 times the gas");
    }

    function _manyConjunctions(uint256 count) internal pure returns (uint256[][] memory conjunctions) {
        conjunctions = new uint256[][](count);
        for (uint256 i = 0; i < count; i++) {
            conjunctions[i] = new uint256[](2);
            conjunctions[i][0] = i + 1;
            conjunctions[i][1] = i + 2;
        }
    }

    // ---------------------------------------------------------------- 6. one literal limit

    function test_ConjunctionAtTheSizeLimitCanBeEvaluated() public {
        // Build a conjunction of 256 literals by doubling: 1, 2, 4, ... 256
        uint256 size = 256;
        uint256[] memory parts = new uint256[](size);
        for (uint256 i = 0; i < size; i++) {
            parts[i] = expr.createLiteralExpression(int256(i + 1));
        }
        while (size > 1) {
            for (uint256 i = 0; i < size / 2; i++) {
                parts[i] = expr.andExpressions(parts[2 * i], parts[2 * i + 1]);
            }
            size /= 2;
        }
        uint256 big = parts[0];
        assertEq(expr.getConjunctions(big)[0].length, 256);

        uint256[] memory ids = new uint256[](256);
        uint256[] memory values = new uint256[](256);
        for (uint256 i = 0; i < 256; i++) {
            ids[i] = i + 1;
            values[i] = SCALE;
        }
        // The old evaluator refused anything above 128 literals, so such a position could never be redeemed
        assertEq(expr.evaluateExpressionWithValues(big, ids, values), SCALE);

        // One literal more cannot be created at all
        uint256 extra = expr.createLiteralExpression(257);
        vm.expectRevert(ExpressionContract.ExpressionTooLarge.selector);
        expr.andExpressions(big, extra);
    }

    // ---------------------------------------------------------------- 7. OR of overlapping expressions

    function test_OrOfOverlappingExpressionsIsRejected() public {
        uint256 x = expr.createLiteralExpression(int256(X));
        uint256 y = expr.createLiteralExpression(int256(Y));

        vm.expectRevert(abi.encodeWithSelector(ExpressionContract.ExpressionsOverlap.selector, x, y));
        expr.orExpressions(x, y);
        vm.expectRevert(abi.encodeWithSelector(ExpressionContract.ExpressionsOverlap.selector, x, y));
        expr.mergeExpressions(x, y);
        vm.expectRevert(abi.encodeWithSelector(ExpressionContract.ExpressionsOverlap.selector, x, x));
        expr.orExpressions(x, x);
        vm.expectRevert(abi.encodeWithSelector(ExpressionContract.ExpressionsOverlap.selector, 1, x));
        expr.orExpressions(1, x);

        assertEq(expr.orExpressions(x, expr.getFalseExpressionId()), x, "X or FALSE is X");
    }

    function test_XOrYIsThreeQuartersAtOneHalfEach() public {
        uint256 x = expr.createLiteralExpression(int256(X));
        uint256 y = expr.createLiteralExpression(int256(Y));
        uint256 notX = expr.createLiteralExpression(-int256(X));

        // "X or Y" in exclusive form: X, plus (not X and Y)
        uint256 xOrY = expr.orExpressions(x, expr.andExpressions(notX, y));
        assertEq(expr.getConjunctions(xOrY).length, 2);

        uint256[] memory ids = _ids(X, Y);
        assertEq(expr.evaluateExpressionWithValues(xOrY, ids, _ids(SCALE / 2, SCALE / 2)), (3 * SCALE) / 4);
        assertEq(expr.evaluateExpressionWithValues(xOrY, ids, _ids(SCALE, SCALE)), SCALE);
        assertEq(expr.evaluateExpressionWithValues(xOrY, ids, _ids(0, 0)), 0);
        assertEq(expr.evaluateExpressionWithValues(xOrY, ids, _ids(0, SCALE)), SCALE);
        assertEq(expr.evaluateExpressionWithValues(xOrY, ids, _ids(SCALE / 4, SCALE / 2)), (5 * SCALE) / 8);
    }

    function test_PositionOnXOrYPaysThreeQuarters() public {
        _deposit(alice, 100);
        (uint256 x, uint256 notX) = _partition(alice, 1, X);
        (uint256 notXAndY, uint256 notXAndNotY) = _partition(alice, notX, Y);

        uint256 xOrY = _merge(alice, x, notXAndY);
        assertEq(_bal(alice, xOrY), 100);

        _settle(X, SCALE / 2);
        _settle(Y, SCALE / 2);
        assertEq(_redeemAll(alice, xOrY), 75);
        assertEq(_redeemAll(alice, notXAndNotY), 25);
        assertEq(usd.balanceOf(address(pt)), 0);
    }

    function test_MergingOverlappingPositionsIsRejected() public {
        _deposit(alice, 100);
        (uint256 x,) = _partition(alice, 1, X);
        _deposit(alice, 100);
        (uint256 y,) = _partition(alice, 1, Y);

        uint256 xPosition = _pid(x);
        uint256 yPosition = _pid(y);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ExpressionContract.ExpressionsOverlap.selector, x, y));
        pt.mergePositions(xPosition, yPosition);
    }

    function test_EvaluateConjunctionNeedsEveryVariable() public {
        uint256 xAndY =
            expr.andExpressions(expr.createLiteralExpression(int256(X)), expr.createLiteralExpression(int256(Y)));
        uint256[] memory onlyX = new uint256[](1);
        onlyX[0] = X;
        uint256[] memory one = new uint256[](1);
        one[0] = SCALE;
        vm.expectRevert(abi.encodeWithSelector(ExpressionEvaluatorLib.VariableValueNotProvided.selector, Y));
        expr.evaluateConjunction(xAndY, 0, onlyX, one);
        assertEq(expr.evaluateConjunction(xAndY, 0, _ids(X, Y), _ids(SCALE / 2, SCALE / 2)), SCALE / 4);
    }

    // ---------------------------------------------------------------- 8. events

    function test_FindEventDoesNotScan() public {
        for (uint256 i = 0; i < 400; i++) {
            events.createEvent(oracle, bytes32(i + 1000));
        }
        uint256 last = events.createEvent(oracle, bytes32("last"));

        uint256 gasBefore = gasleft();
        uint256 found = events.findEvent(oracle, bytes32("last"));
        uint256 gasUsed = gasBefore - gasleft();

        assertEq(found, last);
        assertLt(gasUsed, 20_000, "the old scan cost 1.9M gas at 401 events");

        vm.expectRevert(abi.encodeWithSelector(EventContract.EventDoesNotExist.selector, 0));
        events.findEvent(oracle, bytes32("missing"));
    }

    function test_SameQuestionCannotBeCreatedTwice() public {
        vm.expectRevert(abi.encodeWithSelector(EventContract.EventAlreadyExists.selector, X));
        events.createEvent(oracle, bytes32("X"));

        // The same question for another oracle is another event
        uint256 other = events.createEvent(alice, bytes32("X"));
        assertTrue(other != X);
    }

    function test_ReportPayoutsSettlesTheRightEvent() public {
        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 1;
        payouts[1] = 3;
        vm.prank(oracle);
        events.reportPayouts(bytes32("Y"), payouts);

        (bool settledY, uint256 outcomeY,,) = events.getEventOutcome(Y);
        (bool settledX,,,) = events.getEventOutcome(X);
        assertTrue(settledY);
        assertEq(outcomeY, SCALE / 4);
        assertFalse(settledX);
    }

    function test_EventZeroDoesNotExist() public {
        vm.expectRevert(abi.encodeWithSelector(EventContract.EventDoesNotExist.selector, 0));
        events.getEventOutcome(0);
        vm.expectRevert(abi.encodeWithSelector(EventContract.EventDoesNotExist.selector, 0));
        events.settleEvent(0, SCALE);
    }

    // ---------------------------------------------------------------- 9. found while fixing

    /// @dev Old code: partition on "variable with the negation bit set" minted not-X twice, 200 from 100
    function test_PartitionRejectsANegatedVariable() public {
        _deposit(alice, 100);

        vm.expectRevert(abi.encodeWithSelector(ExpressionContract.InvalidVariable.selector, X | NEG));
        expr.splitExpression(1, X | NEG);
        vm.expectRevert(abi.encodeWithSelector(ExpressionContract.InvalidVariable.selector, 0));
        expr.splitExpression(1, 0);

        uint256 truePosition = _pid(1);
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(EventContract.EventDoesNotExist.selector, X | NEG));
        pt.partitionPosition(truePosition, X | NEG);
        vm.expectRevert(abi.encodeWithSelector(EventContract.EventDoesNotExist.selector, 999));
        pt.partitionPosition(truePosition, 999);
        vm.stopPrank();
        assertEq(_bal(alice, 1), 100);
    }

    function test_FeeOnTransferTokenMintsWhatArrived() public {
        FeeCollateral fee = new FeeCollateral();
        fee.mint(alice, 1000);
        vm.startPrank(alice);
        fee.approve(address(pt), 1000);
        pt.createPosition(fee, 1000);
        uint256 truePosition = pt.getPositionId(fee, 1);
        assertEq(fee.balanceOf(address(pt)), 990);
        assertEq(pt.balanceOf(alice, truePosition), 990, "tokens match the collateral that arrived");
        pt.redeemPosition(truePosition, 990);
        vm.stopPrank();
        assertEq(fee.balanceOf(address(pt)), 0);
    }

    function test_SplitThenMergeOnVariableReturnsTheSameExpression(uint256 seed) public {
        // A random expression with exclusive conjunctions, built by splitting TRUE and keeping random parts
        uint256 e = 1;
        for (uint256 step = 0; step < 6; step++) {
            seed = uint256(keccak256(abi.encode(seed)));
            uint256 variable = 1 + (seed % 5);
            (uint256 a, uint256 b) = expr.splitExpression(e, variable);
            uint256 pick = (seed >> 8) % 3;
            if (pick == 0) {
                e = a;
            } else if (pick == 1) {
                e = b;
            } else {
                // keep one half, split it again on another variable and re-join the two quarters
                uint256 other = 1 + ((seed >> 16) % 5);
                (uint256 c, uint256 d) = expr.splitExpression(a, other);
                e = (c == d) ? a : expr.orExpressions(c, d);
            }
        }
        uint256[] memory used = expr.getExpressionVariables(e);
        for (uint256 variable = 1; variable <= 6; variable++) {
            bool mentioned = false;
            for (uint256 i = 0; i < used.length; i++) {
                if (used[i] == variable) mentioned = true;
            }
            if (mentioned) continue; // only a variable e does not mention splits it into "e and v", "e and not v"
            (uint256 withVar, uint256 withNotVar) = expr.splitExpression(e, variable);
            assertEq(expr.mergeExpressionsOnVariable(withVar, withNotVar, variable), e);
        }
    }

    // ---------------------------------------------------------------- the example: two exclusive bets, one deposit

    function _buildExample() internal returns (uint256[5] memory e) {
        // e[0] = X & !Y & Z, e[1] = X & Y & !Z, leftovers: e[2] = !X, e[3] = X & !Y & !Z, e[4] = X & Y & Z
        _deposit(alice, 100);
        (uint256 x, uint256 notX) = _partition(alice, 1, X);
        (uint256 xy, uint256 xNotY) = _partition(alice, x, Y);
        (uint256 xNotYZ, uint256 xNotYNotZ) = _partition(alice, xNotY, Z);
        (uint256 xyz, uint256 xyNotZ) = _partition(alice, xy, Z);
        e = [xNotYZ, xyNotZ, notX, xNotYNotZ, xyz];
        for (uint256 i = 0; i < 5; i++) {
            assertEq(_bal(alice, e[i]), 100);
        }
        assertEq(usd.balanceOf(address(pt)), 100, "one deposit of 100 backs both bets");
    }

    function test_ExampleMergesBackToTheDeposit() public {
        uint256[5] memory e = _buildExample();

        uint256 xy = _mergeOnVariable(alice, e[4], e[1], Z);
        uint256 xNotY = _mergeOnVariable(alice, e[0], e[3], Z);
        uint256 x = _mergeOnVariable(alice, xy, xNotY, Y);
        uint256 all = _mergeOnVariable(alice, x, e[2], X);

        assertEq(all, 1);
        assertEq(_bal(alice, 1), 100, "four merges give back exactly the deposit");
        assertEq(_redeemAll(alice, 1), 100);
        assertEq(usd.balanceOf(address(pt)), 0);
    }

    function test_ExamplePaysOneBetAfterSettlement() public {
        uint256[5] memory e = _buildExample();
        _settle(X, SCALE);
        _settle(Y, 0);
        _settle(Z, SCALE);

        assertEq(_redeemAll(alice, e[0]), 100, "X and not-Y and Z won");
        assertEq(_redeemAll(alice, e[1]), 0);
        assertEq(_redeemAll(alice, e[2]), 0);
        assertEq(_redeemAll(alice, e[3]), 0);
        assertEq(_redeemAll(alice, e[4]), 0);
        assertEq(usd.balanceOf(address(pt)), 0);
    }

    function test_ExampleTheTwoBetsMergeIntoOnePosition() public {
        uint256[5] memory e = _buildExample();

        uint256 either = _merge(alice, e[0], e[1]);
        assertEq(_bal(alice, either), 100);

        _settle(X, SCALE);
        _settle(Y, SCALE);
        _settle(Z, 0);
        assertEq(_redeemAll(alice, either), 100, "X and Y and not-Z won");
        assertEq(_redeemAll(alice, e[4]), 0);
    }

    // ---------------------------------------------------------------- hostile receiver

    function test_ReceiverCannotReenterDuringAMint() public {
        ReenteringHolder holder = new ReenteringHolder(pt, usd);
        usd.mint(address(holder), 100);
        holder.deposit(100);

        // The holder tries to redeem, partition and merge again from inside every token callback
        holder.arm();
        holder.partition(_pid(1), X);
        assertGt(holder.attempts(), 0, "the callback ran");
        assertEq(holder.successes(), 0, "no call went through while a mint was in progress");

        (uint256 x, uint256 notX) = expr.splitExpression(1, X);
        assertEq(_bal(address(holder), x), 100);
        assertEq(_bal(address(holder), notX), 100);
        assertEq(_bal(address(holder), 1), 0);
        assertEq(usd.balanceOf(address(pt)), 100);
    }
}

/// @dev A token holder that calls back into the position contract whenever it receives tokens
contract ReenteringHolder {
    PositionTokenContract internal pt;
    IERC20 internal token;
    bool internal armed;
    uint256 public attempts;
    uint256 public successes;

    constructor(PositionTokenContract _pt, IERC20 _token) {
        pt = _pt;
        token = _token;
    }

    function deposit(uint256 amount) external {
        token.approve(address(pt), amount);
        pt.createPosition(token, amount);
    }

    function arm() external {
        armed = true;
    }

    function partition(uint256 positionId, uint256 variable) external {
        pt.partitionPosition(positionId, variable);
    }

    function onERC1155Received(address, address, uint256 id, uint256 value, bytes calldata) external returns (bytes4) {
        if (armed) {
            attempts++;
            try pt.redeemPosition(id, value) {
                successes++;
            } catch { }
            try pt.partitionPosition(id, 1) {
                successes++;
            } catch { }
            try pt.createPosition(token, 1) {
                successes++;
            } catch { }
            try pt.evaluatePosition(id) {
                successes++;
            } catch { }
        }
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }
}
