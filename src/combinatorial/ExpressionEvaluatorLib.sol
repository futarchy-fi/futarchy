// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ExpressionEvaluatorLib
 * @notice Evaluates logical expressions with gas safety features
 * @dev The value of a conjunction is the product of its literals' values (1 - value for a negated literal).
 *      The value of an expression is the sum of its conjunctions' values. That sum is the exact value of the
 *      expression, for fractional event values too, as long as no two conjunctions can be true together.
 *      ExpressionContract only stores expressions in that form. Every division rounds down.
 */
library ExpressionEvaluatorLib {
    uint256 private constant SCALE = 1e18;

    /// @dev The one size limit for a conjunction: an expression that can be created can also be evaluated
    uint256 internal constant MAX_LITERALS = 256;
    uint256 internal constant MAX_CONJUNCTIONS = 1024;

    // Conservative round numbers for gas estimation
    uint256 private constant GAS_PER_LITERAL = 5000;
    uint256 private constant GAS_BASE_PER_CONJUNCTION = 10000;
    uint256 private constant GAS_OVERHEAD = 20000;

    error ValueAboveScale(uint256 value);
    error ConjunctionTooLarge(uint256 size);
    error VariableValueNotProvided(uint256 varId);
    error LengthMismatch();

    /**
     * @notice Get complexity metrics for an expression
     */
    function getExpressionComplexity(uint256[][] memory conjunctions)
        internal
        pure
        returns (uint256 totalConjunctions, uint256 maxLiterals, uint256 totalLiterals, uint256 estimatedGas)
    {
        totalConjunctions = conjunctions.length;
        if (totalConjunctions > MAX_CONJUNCTIONS) revert ConjunctionTooLarge(totalConjunctions);

        for (uint256 i = 0; i < conjunctions.length; i++) {
            uint256 numLiterals = conjunctions[i].length;
            if (numLiterals > MAX_LITERALS) revert ConjunctionTooLarge(numLiterals);

            totalLiterals += numLiterals;
            if (numLiterals > maxLiterals) {
                maxLiterals = numLiterals;
            }
        }

        estimatedGas = GAS_OVERHEAD + (totalConjunctions * GAS_BASE_PER_CONJUNCTION) + (totalLiterals * GAS_PER_LITERAL);
    }

    /**
     * @notice Evaluate a single conjunction using arrays of variable IDs and values
     */
    function evaluateConjunctionWithValues(
        uint256[] memory literals,
        uint256[] memory variableIds,
        uint256[] memory variableValues
    ) internal pure returns (uint256) {
        if (literals.length > MAX_LITERALS) revert ConjunctionTooLarge(literals.length);
        if (variableIds.length != variableValues.length) revert LengthMismatch();

        uint256 result = SCALE;

        for (uint256 i = 0; i < literals.length; i++) {
            uint256 literal = literals[i];
            uint256 varId = literal & ((1 << 255) - 1);
            bool isNegated = (literal & (1 << 255)) != 0;

            // Find the value of varId in variableIds and variableValues
            uint256 value = 0;
            bool found = false;
            for (uint256 j = 0; j < variableIds.length; j++) {
                if (variableIds[j] == varId) {
                    value = variableValues[j];
                    found = true;
                    break;
                }
            }
            if (!found) {
                // Variable value not found
                revert VariableValueNotProvided(varId);
            }

            if (value > SCALE) revert ValueAboveScale(value);

            if (isNegated) {
                value = SCALE - value;
            }

            result = (result * value) / SCALE;
            if (result == 0) break;
        }

        return result;
    }

    /**
     * @notice Evaluate an expression using arrays of variable IDs and values
     * @dev The conjunctions must be pairwise mutually exclusive (see the library note). The sum then cannot
     *      exceed SCALE; the cap below is only a guard.
     */
    function evaluateExpressionWithValues(
        uint256[][] memory conjunctions,
        uint256[] memory variableIds,
        uint256[] memory variableValues
    ) internal pure returns (uint256) {
        if (conjunctions.length > MAX_CONJUNCTIONS) {
            revert ConjunctionTooLarge(conjunctions.length);
        }

        uint256 total = 0;

        for (uint256 i = 0; i < conjunctions.length; i++) {
            total += evaluateConjunctionWithValues(conjunctions[i], variableIds, variableValues);
        }
        return total > SCALE ? SCALE : total;
    }
}
