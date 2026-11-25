// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./CombinatorialTestBase.sol";

/**
 * @notice Random sequences of every operation, by several accounts, checked against an independent exact model
 * @dev The model does not use the contracts' evaluator. It reads the conjunctions of an expression, computes
 *      its truth table as a plain OR of ANDs over the 8 yes/no outcomes of three events, and values a token as
 *      the probability-weighted truth, in integers scaled by 1e54 (three factors of 1e18, no rounding).
 *      An event that has not settled is tried at both 0 and 1.
 *
 *      Checked after every step:
 *      - what all tokens can pay, in every outcome, is at most the collateral held;
 *      - the account that acted is not worth more in any outcome than before (deposits and payouts counted);
 *        partition, split and both merges must leave its worth exactly unchanged;
 *      - no stored expression has two conjunctions that are true together.
 *      At the end every event settles and everyone redeems everything: the total paid never exceeds the total
 *      deposited, the difference is rounding dust only, and it is exactly zero when every outcome was 0 or 1.
 */
contract CombinatorialSolvencyTest is CombinatorialTestBase {
    uint256 internal constant EVENTS = 3;
    uint256 internal constant CORNERS = 8;
    uint256 internal constant EXACT = 1e54; // SCALE ** EVENTS
    uint256 internal constant STEPS = 40;

    address[3] internal actors;

    uint256[] internal knownExpressions; // every expression some position has used
    mapping(uint256 => bool) internal isKnown;
    mapping(uint256 => uint256) internal truthTable; // bit c set: true in outcome c (bit i of c = event i+1 is true)

    uint256 internal rng;
    uint256 internal deposited;
    uint256 internal paid;
    uint256 internal roundedSteps; // redemptions and partial evaluations: each may leave under 2 units of dust
    bool internal fractionalOutcome;
    bool internal yesNoOnly;

    function setUp() public override {
        super.setUp();
        actors = [alice, bob, makeAddr("carol")];
        _learn(1);
        _learn(2);
    }

    /// forge-config: default.fuzz.runs = 300
    /// forge-config: ci.fuzz.runs = 300
    function testFuzz_RandomSequencesStaySolvent(uint256 seed) public {
        rng = seed;
        for (uint256 step = 0; step < STEPS; step++) {
            _step();
            _assertSolvent();
        }
        _settleEverythingAndRedeem();
    }

    /// forge-config: default.fuzz.runs = 100
    /// forge-config: ci.fuzz.runs = 100
    function testFuzz_RandomSequencesWithYesNoOutcomesPayBackEverything(uint256 seed) public {
        rng = seed;
        yesNoOnly = true;
        for (uint256 step = 0; step < STEPS; step++) {
            _step();
            _assertSolvent();
        }
        _settleEverythingAndRedeem();
        assertFalse(fractionalOutcome);
    }

    // ------------------------------------------------------------------ one random step

    function _step() internal {
        address actor = actors[_rand(3)];
        uint256 choice = _rand(100);

        if (choice < 14 || deposited == 0) {
            _doDeposit(actor);
        } else if (choice < 36) {
            _doPartition(actor);
        } else if (choice < 44) {
            _doSplitConjunction(actor);
        } else if (choice < 60) {
            _doMergeOnVariable(actor);
        } else if (choice < 72) {
            _doMergeExclusive(actor);
        } else if (choice < 80) {
            _doTransfer(actor);
        } else if (choice < 86) {
            _doSettle();
        } else if (choice < 93) {
            _doPartialEvaluate(actor);
        } else {
            _doRedeem(actor);
        }
    }

    function _doDeposit(address actor) internal {
        uint256 amount = 1 + _rand(1e9);
        uint256[CORNERS] memory beforeWorth = _worth(actor);
        _deposit(actor, amount);
        deposited += amount;
        uint256[CORNERS] memory afterWorth = _worth(actor);
        for (uint256 c = 0; c < CORNERS; c++) {
            assertEq(afterWorth[c], beforeWorth[c] + amount * EXACT, "deposit: worth must grow by the deposit");
        }
    }

    function _doPartition(address actor) internal {
        (uint256 e, bool ok) = _pickHeld(actor);
        if (!ok) return;
        uint256 variable = 1 + _rand(EVENTS);
        uint256[CORNERS] memory beforeWorth = _worth(actor);

        (uint256 a, uint256 b) = _partition(actor, e, variable);
        _learn(a);
        _learn(b);
        _assertSameWorth(actor, beforeWorth, "partition");
    }

    function _doSplitConjunction(address actor) internal {
        (uint256 e, bool ok) = _pickHeld(actor);
        if (!ok) return;
        uint256 count = expr.getConjunctions(e).length;
        if (count == 0) return;
        uint256 index = _rand(count);
        uint256[CORNERS] memory beforeWorth = _worth(actor);

        uint256 positionId = _pid(e);
        vm.prank(actor);
        pt.splitPositionByConjunction(positionId, index);
        (uint256 single, uint256 rest) = expr.splitConjunction(e, index);
        _learn(single);
        _learn(rest);
        _assertSameWorth(actor, beforeWorth, "split by conjunction");
    }

    function _doMergeOnVariable(address actor) internal {
        (uint256 e, bool ok) = _pickHeld(actor);
        if (!ok) return;
        uint256[CORNERS] memory beforeWorth = _worth(actor);

        // Look for a partner the actor holds that merges with e on some variable, in either role
        uint256 start = _rand(knownExpressions.length);
        for (uint256 k = 0; k < knownExpressions.length; k++) {
            uint256 other = knownExpressions[(start + k) % knownExpressions.length];
            if (other == e || _bal(actor, other) == 0) continue;
            for (uint256 variable = 1; variable <= EVENTS; variable++) {
                for (uint256 role = 0; role < 2; role++) {
                    (uint256 withVar, uint256 withNotVar) = role == 0 ? (e, other) : (other, e);
                    try expr.mergeExpressionsOnVariable(withVar, withNotVar, variable) returns (uint256 merged) {
                        _mergeOnVariable(actor, withVar, withNotVar, variable);
                        _learn(merged);
                        _assertSameWorth(actor, beforeWorth, "merge on variable");
                        return;
                    } catch { }
                }
            }
        }
    }

    function _doMergeExclusive(address actor) internal {
        (uint256 e, bool ok) = _pickHeld(actor);
        if (!ok) return;
        uint256[CORNERS] memory beforeWorth = _worth(actor);

        uint256 start = _rand(knownExpressions.length);
        for (uint256 k = 0; k < knownExpressions.length; k++) {
            uint256 other = knownExpressions[(start + k) % knownExpressions.length];
            if (other == e || _bal(actor, other) == 0) continue;

            bool overlap = (truthTable[e] & truthTable[other]) != 0;
            uint256 position1 = _pid(e);
            uint256 position2 = _pid(other);
            if (overlap) {
                // Two positions that can both pay must never merge
                vm.prank(actor);
                vm.expectRevert();
                pt.mergePositions(position1, position2);
                continue;
            }
            try expr.mergeExpressions(e, other) returns (uint256 merged) {
                vm.prank(actor);
                pt.mergePositions(position1, position2);
                _learn(merged);
                assertEq(truthTable[merged], truthTable[e] | truthTable[other], "merge: OR of the two");
                _assertSameWorth(actor, beforeWorth, "merge of exclusive positions");
                return;
            } catch {
                // Never both true, but written so that some pair of conjunctions shares no opposite literal
                // (it can only happen with a contradiction-free pair, so this branch must not be reached)
                revert("exclusive expressions refused to merge");
            }
        }
    }

    function _doTransfer(address actor) internal {
        (uint256 e, bool ok) = _pickHeld(actor);
        if (!ok) return;
        address to = actors[_rand(3)];
        uint256 amount = 1 + _rand(_bal(actor, e));
        uint256 positionId = _pid(e);
        vm.prank(actor);
        pt.safeTransferFrom(actor, to, positionId, amount, "");
    }

    function _doSettle() internal {
        uint256 eventId = 1 + _rand(EVENTS);
        (bool settled,,,) = events.getEventOutcome(eventId);
        if (settled) return;
        _settle(eventId, _randomOutcome());
    }

    function _doPartialEvaluate(address actor) internal {
        (uint256 e, bool ok) = _pickHeld(actor);
        if (!ok) return;
        uint256 variable = 1 + _rand(EVENTS);
        (bool settled,,,) = events.getEventOutcome(variable);
        uint256 positionId = _pid(e);

        if (!settled) {
            vm.prank(actor);
            vm.expectRevert(PositionTokenContract.EventsNotSettled.selector);
            pt.partialEvaluatePosition(positionId, variable);
            return;
        }

        uint256[CORNERS] memory beforeWorth = _worth(actor);
        uint256[] memory one = new uint256[](1);
        one[0] = variable;
        uint256[] memory value = new uint256[](1);
        value[0] = SCALE;
        _learn(expr.simplifyExpression(e, one, value));
        value[0] = 0;
        _learn(expr.simplifyExpression(e, one, value));

        vm.prank(actor);
        pt.partialEvaluatePosition(positionId, variable);
        roundedSteps++;

        uint256[CORNERS] memory afterWorth = _worth(actor);
        for (uint256 c = 0; c < CORNERS; c++) {
            assertLe(afterWorth[c], beforeWorth[c], "partial evaluation: worth must not grow");
            assertLe(beforeWorth[c] - afterWorth[c], 2 * EXACT, "partial evaluation: at most 2 units of dust");
        }
    }

    function _doRedeem(address actor) internal {
        (uint256 e, bool ok) = _pickHeld(actor);
        if (!ok) return;
        uint256 amount = 1 + _rand(_bal(actor, e));
        uint256 positionId = _pid(e);

        if (!_allSettled(e)) {
            vm.prank(actor);
            vm.expectRevert(PositionTokenContract.EventsNotSettled.selector);
            pt.redeemPosition(positionId, amount);
            return;
        }
        _redeem(actor, e, amount);
    }

    function _redeem(address actor, uint256 e, uint256 amount) internal {
        uint256[CORNERS] memory beforeWorth = _worth(actor);
        uint256 balanceBefore = usd.balanceOf(actor);
        uint256 positionId = _pid(e);
        vm.prank(actor);
        pt.redeemPosition(positionId, amount);
        uint256 payout = usd.balanceOf(actor) - balanceBefore;
        paid += payout;
        roundedSteps++;

        // The payout is the exact value of the tokens, rounded down, less under one more unit of dust
        uint256 exact = amount * _exactValue(e, 0);
        assertLe(payout * EXACT, exact, "redeem: payout above the exact value");
        assertLt(exact - payout * EXACT, 2 * EXACT, "redeem: more than dust withheld");

        uint256[CORNERS] memory afterWorth = _worth(actor);
        for (uint256 c = 0; c < CORNERS; c++) {
            assertLe(afterWorth[c] + payout * EXACT, beforeWorth[c], "redeem: worth plus payout must not grow");
        }
    }

    // ------------------------------------------------------------------ end of a sequence

    function _settleEverythingAndRedeem() internal {
        for (uint256 eventId = 1; eventId <= EVENTS; eventId++) {
            (bool settled,,,) = events.getEventOutcome(eventId);
            if (!settled) _settle(eventId, _randomOutcome());
        }
        _assertSolvent();

        for (uint256 a = 0; a < 3; a++) {
            for (uint256 k = 0; k < knownExpressions.length; k++) {
                uint256 balance = _bal(actors[a], knownExpressions[k]);
                if (balance > 0) _redeem(actors[a], knownExpressions[k], balance);
            }
        }

        assertEq(usd.balanceOf(address(pt)), deposited - paid, "collateral held = deposited - paid");
        assertLe(paid, deposited, "paid out more than was deposited");
        assertLe(deposited - paid, 2 * roundedSteps, "more than rounding dust left behind");
        if (!fractionalOutcome) {
            assertEq(paid, deposited, "with yes/no outcomes everything deposited is paid back");
        }
    }

    // ------------------------------------------------------------------ the exact model

    function _assertSolvent() internal view {
        uint256 held = usd.balanceOf(address(pt));
        assertEq(held, deposited - paid, "collateral held = deposited - paid");

        uint256[CORNERS] memory total;
        for (uint256 a = 0; a < 3; a++) {
            uint256[CORNERS] memory worth = _worth(actors[a]);
            for (uint256 c = 0; c < CORNERS; c++) {
                total[c] += worth[c];
            }
        }
        for (uint256 c = 0; c < CORNERS; c++) {
            assertLe(total[c], held * EXACT, "tokens can pay more than the collateral held");
        }
    }

    function _assertSameWorth(address actor, uint256[CORNERS] memory beforeWorth, string memory what) internal view {
        uint256[CORNERS] memory afterWorth = _worth(actor);
        for (uint256 c = 0; c < CORNERS; c++) {
            assertEq(afterWorth[c], beforeWorth[c], what);
        }
    }

    /// @dev What the account's tokens are worth in each outcome of the events that have not settled
    function _worth(address actor) internal view returns (uint256[CORNERS] memory worth) {
        uint256[2][EVENTS] memory weights; // weights[i][1] = value of event i+1, weights[i][0] = 1 - value
        bool[EVENTS] memory isSettled;
        for (uint256 i = 0; i < EVENTS; i++) {
            (bool settled, uint256 outcome,,) = events.getEventOutcome(i + 1);
            isSettled[i] = settled;
            weights[i] = [SCALE - outcome, outcome];
        }

        for (uint256 k = 0; k < knownExpressions.length; k++) {
            uint256 e = knownExpressions[k];
            uint256 balance = _bal(actor, e);
            if (balance == 0) continue;
            for (uint256 c = 0; c < CORNERS; c++) {
                worth[c] += balance * _exactValueAt(truthTable[e], weights, isSettled, c);
            }
        }
    }

    function _exactValue(uint256 e, uint256 corner) internal view returns (uint256) {
        uint256[2][EVENTS] memory weights;
        bool[EVENTS] memory isSettled;
        for (uint256 i = 0; i < EVENTS; i++) {
            (bool settled, uint256 outcome,,) = events.getEventOutcome(i + 1);
            isSettled[i] = settled;
            weights[i] = [SCALE - outcome, outcome];
        }
        return _exactValueAt(truthTable[e], weights, isSettled, corner);
    }

    /// @dev Sum over the 8 yes/no outcomes of (probability of the outcome) * (expression true there), times 1e54
    function _exactValueAt(
        uint256 table,
        uint256[2][EVENTS] memory weights,
        bool[EVENTS] memory isSettled,
        uint256 corner
    ) internal pure returns (uint256 value) {
        for (uint256 outcome = 0; outcome < CORNERS; outcome++) {
            if ((table >> outcome) & 1 == 0) continue;
            uint256 probability = 1;
            for (uint256 i = 0; i < EVENTS; i++) {
                uint256 bit = (outcome >> i) & 1;
                if (isSettled[i]) {
                    probability *= weights[i][bit];
                } else {
                    probability *= ((corner >> i) & 1 == bit) ? SCALE : 0;
                }
            }
            value += probability;
        }
    }

    /// @dev Records an expression: its truth table as an OR of ANDs, and that no two conjunctions overlap
    function _learn(uint256 e) internal {
        if (isKnown[e]) return;
        isKnown[e] = true;
        knownExpressions.push(e);

        uint256[][] memory conjunctions = expr.getConjunctions(e);
        uint256 table = 0;
        for (uint256 outcome = 0; outcome < CORNERS; outcome++) {
            uint256 trueConjunctions = 0;
            for (uint256 i = 0; i < conjunctions.length; i++) {
                bool allTrue = true;
                for (uint256 j = 0; j < conjunctions[i].length; j++) {
                    uint256 literal = conjunctions[i][j];
                    uint256 variable = literal & (NEG - 1);
                    bool wantTrue = literal & NEG == 0;
                    bool isTrue = (outcome >> (variable - 1)) & 1 == 1;
                    if (isTrue != wantTrue) allTrue = false;
                }
                if (allTrue) trueConjunctions++;
            }
            assertLe(trueConjunctions, 1, "two conjunctions of a stored expression are true together");
            if (trueConjunctions == 1) table |= 1 << outcome;
        }
        truthTable[e] = table;

        // The contracts' evaluator must agree with the truth table on every yes/no outcome
        uint256[] memory ids = new uint256[](EVENTS);
        uint256[] memory values = new uint256[](EVENTS);
        for (uint256 outcome = 0; outcome < CORNERS; outcome++) {
            for (uint256 i = 0; i < EVENTS; i++) {
                ids[i] = i + 1;
                values[i] = (outcome >> i) & 1 == 1 ? SCALE : 0;
            }
            assertEq(
                expr.evaluateExpressionWithValues(e, ids, values),
                (table >> outcome) & 1 == 1 ? SCALE : 0,
                "evaluator disagrees with the truth table"
            );
        }
    }

    // ------------------------------------------------------------------ helpers

    function _rand(uint256 bound) internal returns (uint256) {
        rng = uint256(keccak256(abi.encode(rng)));
        return rng % bound;
    }

    function _randomOutcome() internal returns (uint256 outcome) {
        uint256 kind = _rand(yesNoOnly ? 6 : 10);
        if (kind < 3) return 0;
        if (kind < 6) return SCALE;
        fractionalOutcome = true;
        if (kind == 6) return SCALE / 2;
        if (kind == 7) return SCALE / 4;
        if (kind == 8) return 333333333333333333;
        return 1 + _rand(SCALE - 1);
    }

    function _pickHeld(address actor) internal returns (uint256 e, bool ok) {
        uint256 start = _rand(knownExpressions.length);
        for (uint256 k = 0; k < knownExpressions.length; k++) {
            e = knownExpressions[(start + k) % knownExpressions.length];
            if (_bal(actor, e) > 0) return (e, true);
        }
        return (0, false);
    }

    function _allSettled(uint256 e) internal view returns (bool) {
        uint256[] memory variables = expr.getExpressionVariables(e);
        for (uint256 i = 0; i < variables.length; i++) {
            (bool settled,,,) = events.getEventOutcome(variables[i]);
            if (!settled) return false;
        }
        return true;
    }
}
