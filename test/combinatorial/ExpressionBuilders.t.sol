// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./CombinatorialTestBase.sol";

/**
 * @notice Random sequences of every expression builder, checked against truth tables over four variables
 * @dev For each new expression the test reads its conjunctions and requires that
 *      - no two conjunctions are true in the same outcome (so the plain sum is the exact value), and
 *      - the OR of the conjunctions is the truth table the operation should give.
 *      It also compares the contract's value at random fractional event values with the exact value, computed
 *      as the probability-weighted truth table in integers scaled by 1e72.
 */
contract ExpressionBuildersTest is CombinatorialTestBase {
    uint256 internal constant VARS = 4;
    uint256 internal constant OUTCOMES = 16;
    uint256 internal constant ALL = 0xFFFF;
    uint256 internal constant EXACT = 1e72; // SCALE ** VARS

    uint256[] internal ids;
    mapping(uint256 => uint256) internal table; // truth table of each expression made so far, plus one
    uint256 internal rng;

    /// forge-config: default.fuzz.runs = 300
    /// forge-config: ci.fuzz.runs = 300
    function testFuzz_BuildersMatchTruthTables(uint256 seed) public {
        rng = seed;
        _record(1, ALL);
        _record(2, 0);

        for (uint256 step = 0; step < 40; step++) {
            uint256 a = ids[_rand(ids.length)];
            uint256 b = ids[_rand(ids.length)];
            uint256 variable = 1 + _rand(VARS);
            uint256 op = _rand(8);

            if (op == 0) {
                bool negated = _rand(2) == 1;
                uint256 e = expr.createLiteralExpression(negated ? -int256(variable) : int256(variable));
                _record(e, negated ? ALL & ~_mask(variable) : _mask(variable));
            } else if (op == 1) {
                _record(expr.andExpressions(a, b), _table(a) & _table(b));
            } else if (op == 2) {
                _record(expr.intersectExpressions(a, b), _table(a) & _table(b));
            } else if (op == 3 || op == 4) {
                if (_table(a) & _table(b) != 0) {
                    vm.expectRevert(abi.encodeWithSelector(ExpressionContract.ExpressionsOverlap.selector, a, b));
                    if (op == 3) expr.orExpressions(a, b);
                    else expr.mergeExpressions(a, b);
                } else {
                    uint256 e = op == 3 ? expr.orExpressions(a, b) : expr.mergeExpressions(a, b);
                    _record(e, _table(a) | _table(b));
                }
                assertEq(expr.expressionsHaveIntersection(a, b), _table(a) & _table(b) != 0);
            } else if (op == 5) {
                (uint256 withVar, uint256 withNotVar) = expr.splitExpression(a, variable);
                _record(withVar, _table(a) & _mask(variable));
                _record(withNotVar, _table(a) & ~_mask(variable));
                // What was split merges back into the same function, when it merges at all
                try expr.mergeExpressionsOnVariable(withVar, withNotVar, variable) returns (uint256 merged) {
                    _record(merged, _table(a));
                } catch { }
            } else if (op == 6) {
                uint256 count = expr.getConjunctions(a).length;
                if (count == 0) continue;
                (uint256 single, uint256 rest) = expr.splitConjunction(a, _rand(count));
                _learn(single);
                _learn(rest);
                assertEq(_table(single) & _table(rest), 0, "the two parts overlap");
                assertEq(_table(single) | _table(rest), _table(a), "the two parts do not add up");
            } else {
                bool value = _rand(2) == 1;
                uint256[] memory one = new uint256[](1);
                one[0] = variable;
                uint256[] memory values = new uint256[](1);
                values[0] = value ? SCALE : 0;
                _record(expr.simplifyExpression(a, one, values), _cofactor(_table(a), variable, value));
            }
        }

        // Fractional values: the contract's value is the exact value, rounded down by at most a few wei
        uint256[] memory variableIds = new uint256[](VARS);
        uint256[] memory variableValues = new uint256[](VARS);
        for (uint256 i = 0; i < VARS; i++) {
            variableIds[i] = i + 1;
            variableValues[i] = _rand(SCALE + 1);
        }
        for (uint256 k = 0; k < ids.length; k++) {
            uint256 exact = _exactValue(_table(ids[k]), variableValues);
            uint256 got = expr.evaluateExpressionWithValues(ids[k], variableIds, variableValues) * 1e54;
            assertLe(got, exact, "value above the exact value");
            assertLe(exact - got, OUTCOMES * VARS * 1e54, "value far below the exact value");
        }
    }

    function _record(uint256 e, uint256 expected) internal {
        _learn(e);
        assertEq(_table(e), expected, "wrong truth table");
    }

    function _learn(uint256 e) internal {
        if (table[e] != 0) return;
        ids.push(e);

        uint256[][] memory conjunctions = expr.getConjunctions(e);
        uint256 result = 0;
        for (uint256 outcome = 0; outcome < OUTCOMES; outcome++) {
            uint256 trueConjunctions = 0;
            for (uint256 i = 0; i < conjunctions.length; i++) {
                bool allTrue = true;
                for (uint256 j = 0; j < conjunctions[i].length; j++) {
                    uint256 literal = conjunctions[i][j];
                    bool isTrue = (outcome >> ((literal & (NEG - 1)) - 1)) & 1 == 1;
                    if (isTrue != (literal & NEG == 0)) allTrue = false;
                }
                if (allTrue) trueConjunctions++;
            }
            assertLe(trueConjunctions, 1, "two conjunctions are true together");
            if (trueConjunctions == 1) result |= 1 << outcome;
        }
        table[e] = result + 1;
    }

    function _table(uint256 e) internal view returns (uint256) {
        return table[e] - 1;
    }

    /// @dev Outcomes in which the variable is true
    function _mask(uint256 variable) internal pure returns (uint256 mask) {
        for (uint256 outcome = 0; outcome < OUTCOMES; outcome++) {
            if ((outcome >> (variable - 1)) & 1 == 1) mask |= 1 << outcome;
        }
    }

    /// @dev The table with the variable fixed to a value
    function _cofactor(uint256 t, uint256 variable, bool value) internal pure returns (uint256 result) {
        uint256 bit = 1 << (variable - 1);
        for (uint256 outcome = 0; outcome < OUTCOMES; outcome++) {
            uint256 fixedOutcome = value ? outcome | bit : outcome & ~bit;
            if ((t >> fixedOutcome) & 1 == 1) result |= 1 << outcome;
        }
    }

    function _exactValue(uint256 t, uint256[] memory values) internal pure returns (uint256 value) {
        for (uint256 outcome = 0; outcome < OUTCOMES; outcome++) {
            if ((t >> outcome) & 1 == 0) continue;
            uint256 probability = 1;
            for (uint256 i = 0; i < VARS; i++) {
                probability *= (outcome >> i) & 1 == 1 ? values[i] : SCALE - values[i];
            }
            value += probability;
        }
    }

    function _rand(uint256 bound) internal returns (uint256) {
        rng = uint256(keccak256(abi.encode(rng)));
        return rng % bound;
    }
}
