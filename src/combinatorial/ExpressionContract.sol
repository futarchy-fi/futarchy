// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CanonicalFormLib.sol";
import "./ExpressionEvaluatorLib.sol";

/**
 * @title ExpressionContract
 * @notice Manages logical expressions in DNF form with evaluation capabilities
 * @dev Every stored expression is in canonical form (see CanonicalFormLib) and its conjunctions are pairwise
 *      mutually exclusive: no two of them can be true together. That is what makes the value of an expression
 *      the plain sum of its conjunctions' values, also when events settle at a fraction. "X or Y" is therefore
 *      stored as "X" plus "not X and Y" (value x + (1 - x) * y), never as "X" plus "Y".
 */
contract ExpressionContract {
    using CanonicalFormLib for uint256[][];
    using ExpressionEvaluatorLib for uint256[][];

    uint256 private constant MAX_LITERALS = ExpressionEvaluatorLib.MAX_LITERALS;
    uint256 private constant MAX_CONJUNCTIONS = ExpressionEvaluatorLib.MAX_CONJUNCTIONS;
    uint256 private constant NEGATION_BIT = 1 << 255;

    error ExpressionDoesNotExist(uint256 expressionId);
    error InvalidLiteral();
    error ExpressionTooLarge();
    error InvalidBooleanValue(uint256 value);
    error LengthMismatch();
    error ExpressionsCannotBeMerged();
    error InvalidVariable(uint256 variable);
    /// @notice The two expressions can be true together, so their OR cannot be stored as a plain union
    error ExpressionsOverlap(uint256 exprId1, uint256 exprId2);
    /// @notice Two conjunctions of the expression being created can be true together
    error ConjunctionsNotExclusive(uint256 firstIndex, uint256 secondIndex);

    uint256 public constant SCALE = 1e18;

    struct Expression {
        uint256 expressionId;
        uint256[][] conjunctions;
    }

    uint256 private nextExpressionId = 1;
    mapping(uint256 => Expression) public expressions;
    mapping(bytes32 => uint256) private expressionHashes;

    event ExpressionCreated(uint256 indexed expressionId, bytes32 indexed hash);

    constructor() {
        // Create TRUE expression (expressionId = 1)
        uint256[][] memory trueExpr = new uint256[][](1);
        trueExpr[0] = new uint256[](0);
        _createExpression(trueExpr);

        // Create FALSE expression (expressionId = 2)
        uint256[][] memory falseExpr = new uint256[][](0);
        _createExpression(falseExpr);
    }

    /**
     * @notice Creates a literal expression
     */
    function createLiteralExpression(int256 literal) public returns (uint256) {
        if (literal == 0 || literal == type(int256).min) revert InvalidLiteral();

        uint256[][] memory conj = new uint256[][](1);
        conj[0] = new uint256[](1);
        conj[0][0] = literal > 0 ? uint256(literal) : (uint256(-literal) | NEGATION_BIT);

        return _createExpression(conj);
    }

    /**
     * @notice Get the TRUE expression ID
     */
    function getTrueExpressionId() public pure returns (uint256) {
        return 1;
    }

    /**
     * @notice Get the FALSE expression ID
     */
    function getFalseExpressionId() public pure returns (uint256) {
        return 2;
    }

    function expressionExists(uint256 expressionId) external view returns (bool) {
        return expressions[expressionId].expressionId != 0;
    }

    /**
     * @notice Returns the conjunctions of an expression in canonical form
     */
    function getConjunctions(uint256 expressionId) external view returns (uint256[][] memory) {
        return _getExpression(expressionId).conjunctions;
    }

    /**
     * @notice Combines two expressions that cannot be true together with OR
     * @dev Reverts with ExpressionsOverlap when some conjunction of one can be true together with some
     *      conjunction of the other. To OR overlapping expressions, first split one of them so that the parts
     *      are exclusive, for example "X or Y" as "X" plus "not X and Y".
     */
    function orExpressions(uint256 exprId1, uint256 exprId2) public returns (uint256) {
        return _exclusiveUnion(exprId1, exprId2);
    }

    /**
     * @notice Combines expressions with AND
     * @dev Pairs of conjunctions that contradict each other drop out. The result keeps the conjunctions
     *      pairwise exclusive because both inputs have them so.
     */
    function andExpressions(uint256 exprId1, uint256 exprId2) public returns (uint256) {
        Expression storage expr1 = _getExpression(exprId1);
        Expression storage expr2 = _getExpression(exprId2);

        uint256 count1 = expr1.conjunctions.length;
        uint256 count2 = expr2.conjunctions.length;
        if (count1 * count2 > MAX_CONJUNCTIONS) {
            revert ExpressionTooLarge();
        }

        uint256[][] memory combined = new uint256[][](count1 * count2);
        uint256 index = 0;

        for (uint256 i = 0; i < count1; i++) {
            uint256[] memory conj1 = expr1.conjunctions[i];
            for (uint256 j = 0; j < count2; j++) {
                uint256[] memory conj2 = expr2.conjunctions[j];

                uint256[] memory literals = new uint256[](conj1.length + conj2.length);
                for (uint256 k = 0; k < conj1.length; k++) {
                    literals[k] = conj1[k];
                }
                for (uint256 k = 0; k < conj2.length; k++) {
                    literals[conj1.length + k] = conj2[k];
                }

                combined[index++] = literals;
            }
        }

        return _createExpression(combined);
    }

    /**
     * @notice Splits an expression into two based on a variable
     * @param expressionId Expression to split
     * @param variable Variable to split on
     * @return withVar Expression AND variable
     * @return withNotVar Expression AND NOT variable
     */
    function splitExpression(uint256 expressionId, uint256 variable)
        public
        returns (uint256 withVar, uint256 withNotVar)
    {
        _requireVariable(variable);

        Expression storage expr = _getExpression(expressionId);
        uint256 numConjunctions = expr.conjunctions.length;

        // Initialize arrays for new expressions
        uint256[][] memory conjWithVar = new uint256[][](numConjunctions);
        uint256[][] memory conjWithNotVar = new uint256[][](numConjunctions);

        for (uint256 i = 0; i < numConjunctions; i++) {
            uint256 origConjLength = expr.conjunctions[i].length;

            // Create new conjunctions with added variable
            uint256[] memory newConjWithVar = new uint256[](origConjLength + 1);
            uint256[] memory newConjWithNotVar = new uint256[](origConjLength + 1);

            // Copy original literals
            for (uint256 j = 0; j < origConjLength; j++) {
                newConjWithVar[j] = expr.conjunctions[i][j];
                newConjWithNotVar[j] = expr.conjunctions[i][j];
            }

            // Add variable and its negation
            newConjWithVar[origConjLength] = variable;
            newConjWithNotVar[origConjLength] = variable | NEGATION_BIT;

            conjWithVar[i] = newConjWithVar;
            conjWithNotVar[i] = newConjWithNotVar;
        }

        // Conjunctions that already contain the opposite literal are contradictions and drop out
        withVar = _createExpression(conjWithVar);
        withNotVar = _createExpression(conjWithNotVar);
    }

    function splitConjunction(uint256 expressionId, uint256 conjunctionIndex)
        public
        returns (uint256 singleConjExprId, uint256 remainingExprId)
    {
        Expression storage expr = _getExpression(expressionId);

        if (conjunctionIndex >= expr.conjunctions.length) {
            revert ExpressionDoesNotExist(conjunctionIndex);
        }

        // Create the expression with the single conjunction
        uint256[][] memory singleConj = new uint256[][](1);
        singleConj[0] = expr.conjunctions[conjunctionIndex];
        singleConjExprId = _createExpression(singleConj);

        // Create the expression with the remaining conjunctions
        uint256 remainingConjLength = expr.conjunctions.length - 1;

        uint256[][] memory remainingConj = new uint256[][](remainingConjLength);
        uint256 index = 0;
        for (uint256 i = 0; i < expr.conjunctions.length; i++) {
            if (i != conjunctionIndex) {
                remainingConj[index++] = expr.conjunctions[i];
            }
        }
        remainingExprId = _createExpression(remainingConj);
    }

    function mergeExpressionsOnVariable(uint256 exprWithVarId, uint256 exprWithNotVarId, uint256 variable)
        public
        returns (uint256 mergedExprId)
    {
        _requireVariable(variable);

        Expression storage exprWithVar = _getExpression(exprWithVarId);
        Expression storage exprWithNotVar = _getExpression(exprWithNotVarId);

        // Strip the variable from both expressions. Removing a literal can change the order of the
        // conjunctions, so both sides go back to canonical form before they are compared.
        uint256[][] memory strippedConj1 =
            stripVariableFromConjunctions(exprWithVar.conjunctions, variable, false).canonicalizeExpression();
        uint256[][] memory strippedConj2 =
            stripVariableFromConjunctions(exprWithNotVar.conjunctions, variable, true).canonicalizeExpression();

        // Compute hashes to compare the stripped expressions
        bytes32 hash1 = strippedConj1.computeExpressionHash();
        bytes32 hash2 = strippedConj2.computeExpressionHash();

        if (hash1 != hash2) {
            revert ExpressionsCannotBeMerged();
        }

        // Create the merged expression (E)
        mergedExprId = _createExpression(strippedConj1);
    }

    function stripVariableFromConjunctions(uint256[][] memory conjunctions, uint256 variable, bool isNegated)
        private
        pure
        returns (uint256[][] memory strippedConjunctions)
    {
        strippedConjunctions = new uint256[][](conjunctions.length);

        for (uint256 i = 0; i < conjunctions.length; i++) {
            uint256[] memory conj = conjunctions[i];
            uint256[] memory tempConj = new uint256[](conj.length);
            uint256 index = 0;
            bool foundVar = false;

            for (uint256 j = 0; j < conj.length; j++) {
                uint256 lit = conj[j];
                uint256 varId = lit & (NEGATION_BIT - 1);
                bool litIsNegated = (lit & NEGATION_BIT) != 0;

                if (varId == variable && litIsNegated == isNegated) {
                    foundVar = true;
                    // Skip this literal
                } else {
                    tempConj[index++] = lit;
                }
            }

            if (!foundVar) {
                // Variable not found in conjunction; cannot merge
                revert ExpressionsCannotBeMerged();
            }

            // Resize the array to the actual number of literals
            uint256[] memory newConj = new uint256[](index);
            for (uint256 k = 0; k < index; k++) {
                newConj[k] = tempConj[k];
            }

            strippedConjunctions[i] = newConj;
        }
    }

    /**
     * @notice Merges two expressions that cannot be true together into their OR
     * @dev Same rule as orExpressions: reverts with ExpressionsOverlap when the two can be true together.
     */
    function mergeExpressions(uint256 exprId1, uint256 exprId2) public returns (uint256 mergedExprId) {
        mergedExprId = _exclusiveUnion(exprId1, exprId2);
    }

    /**
     * @notice Computes intersection of two expressions
     * @param expr1Id First expression
     * @param expr2Id Second expression
     * @return intersectionId Intersection of expressions
     */
    function intersectExpressions(uint256 expr1Id, uint256 expr2Id) public returns (uint256 intersectionId) {
        intersectionId = andExpressions(expr1Id, expr2Id);
    }

    /**
     * @notice Simplifies an expression based on settled variables
     * @param expressionId The ID of the expression to simplify
     * @param variableIds Array of variable IDs that have been settled
     * @param variableValues Array of corresponding settled values
     * @return simplifiedExprId The ID of the simplified expression
     */
    function simplifyExpression(uint256 expressionId, uint256[] memory variableIds, uint256[] memory variableValues)
        public
        returns (uint256 simplifiedExprId)
    {
        if (variableIds.length != variableValues.length) revert LengthMismatch();

        // Ensure all variable values are 0 or SCALE
        // Cannot simplify expressions with values settled to intermediate values
        for (uint256 i = 0; i < variableValues.length; i++) {
            uint256 val = variableValues[i];
            if (val != 0 && val != SCALE) revert InvalidBooleanValue(val);
        }

        Expression storage expr = _getExpression(expressionId);
        uint256 conjCount = expr.conjunctions.length;

        // Prepare a new set of conjunctions after simplification
        uint256[][] memory newConjunctions = new uint256[][](conjCount);
        uint256 newConjCount = 0;

        for (uint256 i = 0; i < conjCount; i++) {
            (bool removeConj, uint256[] memory finalConj) =
                _simplifyConjunction(expr.conjunctions[i], variableIds, variableValues);
            if (!removeConj) {
                newConjunctions[newConjCount++] = finalConj;
            }
        }

        // Resize final array
        uint256[][] memory finalConjunctions = new uint256[][](newConjCount);
        for (uint256 m = 0; m < newConjCount; m++) {
            finalConjunctions[m] = newConjunctions[m];
        }

        simplifiedExprId = _createExpression(finalConjunctions);
    }

    function _simplifyConjunction(uint256[] memory conj, uint256[] memory variableIds, uint256[] memory variableValues)
        internal
        pure
        returns (bool removeConj, uint256[] memory finalConj)
    {
        uint256[] memory tempLiterals = new uint256[](conj.length);
        uint256 litCount = 0;

        for (uint256 j = 0; j < conj.length; j++) {
            uint256 literal = conj[j];
            (bool isSettled, uint256 settledVal) = _getSettledValue(literal, variableIds, variableValues);

            if (isSettled) {
                // If settledVal == 0, this literal is false => entire conjunction is removed
                if (settledVal == 0) {
                    return (true, new uint256[](0));
                }
                // Else settledVal == SCALE (this function cannot be called with intermediate values)
                // So literal is true => omit this literal and continue
            } else {
                // Variable not settled, keep this literal
                tempLiterals[litCount++] = literal;
            }
        }

        // Conjunction not removed
        finalConj = new uint256[](litCount);
        for (uint256 x = 0; x < litCount; x++) {
            finalConj[x] = tempLiterals[x];
        }
        removeConj = false;
    }

    function _getSettledValue(uint256 literal, uint256[] memory variableIds, uint256[] memory variableValues)
        internal
        pure
        returns (bool, uint256)
    {
        uint256 varId = literal & ((1 << 255) - 1);
        bool isNegated = (literal & (1 << 255)) != 0;

        for (uint256 k = 0; k < variableIds.length; k++) {
            if (variableIds[k] == varId) {
                uint256 settledVal = variableValues[k];
                if (isNegated) {
                    settledVal = SCALE - settledVal;
                }
                return (true, settledVal);
            }
        }

        return (false, 0);
    }

    function expressionsHaveIntersection(uint256 exprId1, uint256 exprId2) public view returns (bool hasIntersection) {
        Expression storage expr1 = _getExpression(exprId1);
        Expression storage expr2 = _getExpression(exprId2);

        // The expressions intersect when some pair of conjunctions can be true together
        for (uint256 i = 0; i < expr1.conjunctions.length; i++) {
            uint256[] memory conj1 = expr1.conjunctions[i];
            for (uint256 j = 0; j < expr2.conjunctions.length; j++) {
                if (!CanonicalFormLib.areConjunctionsExclusive(conj1, expr2.conjunctions[j])) {
                    return true; // Intersection exists
                }
            }
        }
        return false; // No intersection
    }

    /**
     * @notice Get complexity metrics for an expression
     */
    function getExpressionComplexity(uint256 expressionId)
        public
        view
        returns (uint256 totalConjunctions, uint256 maxLiterals, uint256 totalLiterals, uint256 estimatedGas)
    {
        Expression storage expr = _getExpression(expressionId);
        return expr.conjunctions.getExpressionComplexity();
    }

    /**
     * @notice Gets all unique variables used in an expression
     * @param expressionId The expression to analyze
     * @return variables Array of variable IDs (without negation flags)
     */
    function getExpressionVariables(uint256 expressionId) public view returns (uint256[] memory variables) {
        Expression storage expr = _getExpression(expressionId);

        // Collect all variables in a temporary array
        uint256 totalLiterals;
        for (uint256 i = 0; i < expr.conjunctions.length; i++) {
            totalLiterals += expr.conjunctions[i].length;
        }

        uint256[] memory allVars = new uint256[](totalLiterals);
        uint256 idx = 0;
        for (uint256 i = 0; i < expr.conjunctions.length; i++) {
            for (uint256 j = 0; j < expr.conjunctions[i].length; j++) {
                uint256 varId = expr.conjunctions[i][j] & ((1 << 255) - 1);
                allVars[idx++] = varId;
            }
        }

        // Extract unique variables from allVars
        // A simple method: for each varId in allVars, check if we have added it before
        uint256[] memory uniqueVars = new uint256[](totalLiterals);
        uint256 uniqueCount = 0;
        for (uint256 i = 0; i < allVars.length; i++) {
            uint256 v = allVars[i];
            bool alreadyAdded = false;
            for (uint256 k = 0; k < uniqueCount; k++) {
                if (uniqueVars[k] == v) {
                    alreadyAdded = true;
                    break;
                }
            }
            if (!alreadyAdded) {
                uniqueVars[uniqueCount++] = v;
            }
        }

        variables = new uint256[](uniqueCount);
        for (uint256 i = 0; i < uniqueCount; i++) {
            variables[i] = uniqueVars[i];
        }
    }

    /**
     * @notice Evaluate a single conjunction of an expression
     * @dev Reverts if a variable of the conjunction has no value, like the evaluation of a whole expression
     */
    function evaluateConjunction(
        uint256 expressionId,
        uint256 conjunctionIndex,
        uint256[] memory variableIds,
        uint256[] memory variableValues
    ) public view returns (uint256) {
        Expression storage expr = _getExpression(expressionId);
        if (conjunctionIndex >= expr.conjunctions.length) revert ExpressionDoesNotExist(conjunctionIndex);

        return ExpressionEvaluatorLib.evaluateConjunctionWithValues(
            expr.conjunctions[conjunctionIndex], variableIds, variableValues
        );
    }

    /**
     * @notice Evaluate an expression: the sum of its conjunctions, exact because they are exclusive
     */
    function evaluateExpressionWithValues(
        uint256 expressionId,
        uint256[] memory variableIds,
        uint256[] memory variableValues
    ) public view returns (uint256) {
        Expression storage expr = _getExpression(expressionId);
        return ExpressionEvaluatorLib.evaluateExpressionWithValues(expr.conjunctions, variableIds, variableValues);
    }

    /**
     * @notice OR of two expressions whose conjunctions are exclusive across the two
     */
    function _exclusiveUnion(uint256 exprId1, uint256 exprId2) private returns (uint256) {
        Expression storage expr1 = _getExpression(exprId1);
        Expression storage expr2 = _getExpression(exprId2);

        uint256 count1 = expr1.conjunctions.length;
        uint256 count2 = expr2.conjunctions.length;
        if (count1 + count2 > MAX_CONJUNCTIONS) {
            revert ExpressionTooLarge();
        }

        uint256[][] memory combined = new uint256[][](count1 + count2);
        for (uint256 i = 0; i < count1; i++) {
            combined[i] = expr1.conjunctions[i];
        }
        for (uint256 i = 0; i < count2; i++) {
            combined[count1 + i] = expr2.conjunctions[i];
        }

        uint256[][] memory canonical = combined.canonicalizeExpression();

        // A conjunction present in both shrinks the list; any other overlap shows up as a non-exclusive pair
        if (canonical.length != count1 + count2) revert ExpressionsOverlap(exprId1, exprId2);
        (bool overlaps,,) = canonical.findOverlappingConjunctions();
        if (overlaps) revert ExpressionsOverlap(exprId1, exprId2);

        return _storeExpression(canonical);
    }

    /**
     * @notice Internal helper to create expression in canonical form
     * @dev Refuses any expression with two conjunctions that can be true together
     */
    function _createExpression(uint256[][] memory conjunctions) private returns (uint256) {
        uint256[][] memory canonical = conjunctions.canonicalizeExpression();

        (bool overlaps, uint256 first, uint256 second) = canonical.findOverlappingConjunctions();
        if (overlaps) revert ConjunctionsNotExclusive(first, second);

        return _storeExpression(canonical);
    }

    /**
     * @notice Stores a canonical expression with exclusive conjunctions, or returns the id it already has
     */
    function _storeExpression(uint256[][] memory canonical) private returns (uint256) {
        if (canonical.length > MAX_CONJUNCTIONS) revert ExpressionTooLarge();
        for (uint256 i = 0; i < canonical.length; i++) {
            if (canonical[i].length > MAX_LITERALS) revert ExpressionTooLarge();
        }

        bytes32 hash = canonical.computeExpressionHash();
        uint256 existingId = expressionHashes[hash];
        if (existingId != 0) {
            return existingId;
        }

        uint256 expressionId = nextExpressionId++;
        Expression storage expr = expressions[expressionId];
        expr.expressionId = expressionId;
        expr.conjunctions = canonical;
        expressionHashes[hash] = expressionId;

        emit ExpressionCreated(expressionId, hash);
        return expressionId;
    }

    function _requireVariable(uint256 variable) private pure {
        if (variable == 0 || variable & NEGATION_BIT != 0) revert InvalidVariable(variable);
    }

    /**
     * @notice Internal helper to get expression with validation
     */
    function _getExpression(uint256 expressionId) private view returns (Expression storage expr) {
        expr = expressions[expressionId];
        if (expr.expressionId == 0) revert ExpressionDoesNotExist(expressionId);
        return expr;
    }
}
