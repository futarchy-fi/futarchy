// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title CanonicalFormLib
 * @notice Library for converting expressions to canonical form and computing their hashes
 * @dev An expression is a list of conjunctions (clauses); a conjunction is a list of literals. A literal is a
 *      variable id with bit 255 set when negated. In canonical form the literals of a conjunction are sorted by
 *      (variable, sign) with no duplicates and no contradiction, and the conjunctions are sorted with no duplicates.
 *      TRUE is one empty conjunction; FALSE is no conjunction at all.
 */
library CanonicalFormLib {
    uint256 private constant NEGATION_BIT = 1 << 255;
    uint256 private constant VARIABLE_MASK = NEGATION_BIT - 1;

    /**
     * @notice Sort key of a literal: orders by variable first, then by sign
     * @dev x and NOT x become neighbours, so one pass over the sorted literals finds every contradiction
     */
    function literalKey(uint256 literal) internal pure returns (uint256) {
        return (literal << 1) | (literal >> 255);
    }

    /**
     * @notice Sorts and deduplicates literals within a conjunction
     * @dev Also detects contradictions (x AND NOT x), wherever the two literals sit in the input
     * @param literals Array of literals to canonicalize (sorted in place)
     * @return cleanLiterals Sorted array with no duplicates
     * @return isValid False if conjunction contains a contradiction
     */
    function canonicalizeConjunction(uint256[] memory literals)
        internal
        pure
        returns (uint256[] memory cleanLiterals, bool isValid)
    {
        if (literals.length == 0) {
            return (new uint256[](0), true);
        }

        // Sort literals by (variable, sign)
        quickSortLiterals(literals, 0, int256(literals.length - 1));

        // Remove duplicates and check for contradictions
        uint256[] memory tempLiterals = new uint256[](literals.length);
        uint256 writeIndex = 0;

        for (uint256 readIndex = 0; readIndex < literals.length; readIndex++) {
            uint256 currentLiteral = literals[readIndex];

            if (readIndex > 0) {
                uint256 prevLiteral = literals[readIndex - 1];

                // Skip duplicates
                if (currentLiteral == prevLiteral) {
                    continue;
                }

                // Same variable with the other sign: contradiction
                if ((currentLiteral & VARIABLE_MASK) == (prevLiteral & VARIABLE_MASK)) {
                    return (new uint256[](0), false);
                }
            }

            tempLiterals[writeIndex++] = currentLiteral;
        }

        // Trim array to final size
        assembly {
            mstore(tempLiterals, writeIndex)
        }

        return (tempLiterals, true);
    }

    /**
     * @notice Puts an entire expression in canonical form
     * @dev Contradictory conjunctions are dropped. An empty conjunction is kept: it is TRUE.
     * @param conjunctions Array of conjunctions to canonicalize
     * @return canonicalForm The expression in canonical form
     */
    function canonicalizeExpression(uint256[][] memory conjunctions)
        internal
        pure
        returns (uint256[][] memory canonicalForm)
    {
        if (conjunctions.length == 0) {
            return new uint256[][](0);
        }

        // First canonicalize each conjunction
        uint256[][] memory validConjunctions = new uint256[][](conjunctions.length);
        uint256 validCount = 0;

        for (uint256 i = 0; i < conjunctions.length; i++) {
            (uint256[] memory cleanConj, bool isValid) = canonicalizeConjunction(conjunctions[i]);
            if (isValid) {
                // Skip contradictory conjunctions only
                validConjunctions[validCount++] = cleanConj;
            }
        }

        // Sort conjunctions for canonical form
        if (validCount > 0) {
            quickSortConjunctions(validConjunctions, 0, int256(validCount - 1));
        }

        // Remove duplicate conjunctions
        canonicalForm = new uint256[][](validCount);
        uint256 writeIndex = 0;

        for (uint256 readIndex = 0; readIndex < validCount; readIndex++) {
            if (readIndex > 0 && areConjunctionsEqual(validConjunctions[readIndex], validConjunctions[readIndex - 1])) {
                continue;
            }
            canonicalForm[writeIndex++] = validConjunctions[readIndex];
        }

        // Trim array to final size
        assembly {
            mstore(canonicalForm, writeIndex)
        }

        return canonicalForm;
    }

    /**
     * @notice Whether two canonical conjunctions can never both be true
     * @dev True exactly when some variable appears plain in one and negated in the other.
     *      Both inputs must be sorted by (variable, sign), as canonicalizeConjunction leaves them.
     */
    function areConjunctionsExclusive(uint256[] memory conj1, uint256[] memory conj2) internal pure returns (bool) {
        uint256 i = 0;
        uint256 j = 0;
        while (i < conj1.length && j < conj2.length) {
            uint256 lit1 = conj1[i];
            uint256 lit2 = conj2[j];
            uint256 var1 = lit1 & VARIABLE_MASK;
            uint256 var2 = lit2 & VARIABLE_MASK;
            if (var1 == var2) {
                if (lit1 != lit2) return true;
                i++;
                j++;
            } else if (var1 < var2) {
                i++;
            } else {
                j++;
            }
        }
        return false;
    }

    /**
     * @notice Finds two conjunctions of a canonical expression that can both be true
     * @return found True if such a pair exists
     * @return first Index of the first conjunction of the pair
     * @return second Index of the second conjunction of the pair
     */
    function findOverlappingConjunctions(uint256[][] memory conjunctions)
        internal
        pure
        returns (bool found, uint256 first, uint256 second)
    {
        for (uint256 i = 0; i < conjunctions.length; i++) {
            for (uint256 j = i + 1; j < conjunctions.length; j++) {
                if (!areConjunctionsExclusive(conjunctions[i], conjunctions[j])) {
                    return (true, i, j);
                }
            }
        }
        return (false, 0, 0);
    }

    /**
     * @notice Compute hash of expression in canonical form
     * @dev abi.encode keeps the array lengths, so two different expressions never share an encoding,
     *      and the cost is linear in the size of the expression.
     * @param conjunctions Array of conjunctions in canonical form
     * @return Hash of the expression
     */
    function computeExpressionHash(uint256[][] memory conjunctions) internal pure returns (bytes32) {
        // Expression should already be in canonical form when this is called
        return keccak256(abi.encode(conjunctions));
    }

    // Sorting helper functions
    function quickSortLiterals(uint256[] memory arr, int256 left, int256 right) private pure {
        if (left >= right) return;

        uint256 pivot = literalKey(arr[uint256(left + (right - left) / 2)]);
        int256 i = left;
        int256 j = right;

        while (i <= j) {
            while (literalKey(arr[uint256(i)]) < pivot) i++;
            while (literalKey(arr[uint256(j)]) > pivot) j--;

            if (i <= j) {
                (arr[uint256(i)], arr[uint256(j)]) = (arr[uint256(j)], arr[uint256(i)]);
                i++;
                j--;
            }
        }

        if (left < j) quickSortLiterals(arr, left, j);
        if (i < right) quickSortLiterals(arr, i, right);
    }

    function quickSortConjunctions(uint256[][] memory arr, int256 left, int256 right) private pure {
        if (left >= right) return;

        uint256[] memory pivot = arr[uint256(left + (right - left) / 2)];
        int256 i = left;
        int256 j = right;

        while (i <= j) {
            while (compareConjunctions(arr[uint256(i)], pivot) < 0) i++;
            while (compareConjunctions(arr[uint256(j)], pivot) > 0) j--;

            if (i <= j) {
                (arr[uint256(i)], arr[uint256(j)]) = (arr[uint256(j)], arr[uint256(i)]);
                i++;
                j--;
            }
        }

        if (left < j) quickSortConjunctions(arr, left, j);
        if (i < right) quickSortConjunctions(arr, i, right);
    }

    function compareConjunctions(uint256[] memory conj1, uint256[] memory conj2) private pure returns (int256) {
        uint256 minLength = conj1.length < conj2.length ? conj1.length : conj2.length;

        // Compare literals in the same (variable, sign) order used inside a conjunction
        for (uint256 i = 0; i < minLength; i++) {
            uint256 key1 = literalKey(conj1[i]);
            uint256 key2 = literalKey(conj2[i]);
            if (key1 < key2) return -1;
            if (key1 > key2) return 1;
        }

        // If all common literals are equal, shorter conjunction comes first
        if (conj1.length < conj2.length) return -1;
        if (conj1.length > conj2.length) return 1;
        return 0;
    }

    function areConjunctionsEqual(uint256[] memory conj1, uint256[] memory conj2) private pure returns (bool) {
        if (conj1.length != conj2.length) return false;
        for (uint256 i = 0; i < conj1.length; i++) {
            if (conj1[i] != conj2[i]) return false;
        }
        return true;
    }
}
