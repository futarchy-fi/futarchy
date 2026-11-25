// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ExpressionContract.sol";
import "./EventContract.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title PositionTokenContract
 * @notice Manages positions tied to expressions with ERC20 collateral
 * @dev One token of a position pays the value of its expression, between 0 and 1 unit of collateral.
 *      Every operation keeps the total that all tokens can pay at or below the collateral held:
 *      - a deposit mints TRUE tokens one for one;
 *      - partition and split replace tokens of E by tokens whose expressions add up to E;
 *      - a merge burns the same amount from each side and mints that amount of the merged expression;
 *      - partial evaluation uses the settled outcome recorded in EventContract.
 *      Amounts and payouts round down; the dust stays in this contract.
 */
contract PositionTokenContract is ERC1155, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ExpressionEvaluatorLib for uint256[][];

    uint256 private constant SCALE = 1e18;

    struct Position {
        IERC20 collateralToken;
        uint256 expressionId;
        uint256 evaluatedValue; // Cached evaluation result (0 if not evaluated)
        uint256 evaluationTime; // When the position was evaluated (0 if not evaluated)
    }

    ExpressionContract public immutable expressionContract;
    EventContract public immutable eventContract;
    mapping(uint256 => Position) public positions; // positionId => Position

    event PositionCreated(
        uint256 indexed positionId, uint256 indexed expressionId, address indexed collateralToken, uint256 amount
    );
    event PositionRedeemed(
        uint256 indexed positionId,
        uint256 indexed expressionId,
        address indexed collateralToken,
        uint256 amount,
        uint256 payout
    );
    event PositionEvaluated(uint256 indexed positionId, uint256 indexed expressionId, uint256 value, uint256 timestamp);
    event PositionPartiallyEvaluated(
        uint256 indexed positionId, uint256 indexed variableId, uint256 settledValue, uint256 timestamp
    );

    error ExpressionNotFound();
    error CollateralTransferFailed();
    error CollateralMismatch();
    error NoBalanceToRedeem();
    error NoBalanceToSplit();
    error NoBalanceToMerge();
    error NoBalanceToEvaluate();
    error EvaluationTooComplex();
    error EventsNotSettled();
    error InvalidAmount();
    error PositionNotFound();
    error SamePosition();

    constructor(address _expressionContract, address _eventContract, string memory uri) ERC1155(uri) {
        expressionContract = ExpressionContract(_expressionContract);
        eventContract = EventContract(_eventContract);
    }

    /**
     * @notice Generates a unique position ID from collateral token and expression
     */
    function getPositionId(IERC20 collateralToken, uint256 expressionId) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(collateralToken, expressionId)));
    }

    /**
     * @notice Creates a new position backed by ERC20 collateral
     */
    function createPosition(IERC20 collateralToken, uint256 amount) external nonReentrant {
        // Newly created positions always associated with the TRUE expression
        uint256 expressionId = expressionContract.getTrueExpressionId();
        if (amount == 0) revert InvalidAmount();
        if (address(collateralToken) == address(0)) revert CollateralTransferFailed();
        if (!expressionContract.expressionExists(expressionId)) revert ExpressionNotFound();

        uint256 positionId = getPositionId(collateralToken, expressionId);

        // Transfer collateral, and count what actually arrived (a token may take a fee on transfer)
        uint256 balanceBefore = collateralToken.balanceOf(address(this));
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = collateralToken.balanceOf(address(this)) - balanceBefore;
        if (received == 0) revert CollateralTransferFailed();

        _registerPosition(collateralToken, expressionId);

        // Mint position tokens
        _mint(msg.sender, positionId, received, "");

        emit PositionCreated(positionId, expressionId, address(collateralToken), received);
    }

    /**
     * @notice Partitions a position into multiple positions based on a condition
     * @param positionId The ID of the position to partition
     * @param variable The variable (event ID) to partition on
     */
    function partitionPosition(uint256 positionId, uint256 variable) external nonReentrant {
        uint256 userBalance = balanceOf(msg.sender, positionId);
        if (userBalance == 0) revert NoBalanceToSplit();

        Position storage pos = positions[positionId];
        IERC20 collateralToken = pos.collateralToken;
        if (collateralToken == IERC20(address(0))) revert PositionNotFound();

        // The variable must be an existing event (reverts otherwise)
        eventContract.getEventOutcome(variable);

        // Split the expression into two expressions: withVar and withNotVar
        (uint256 exprWithVarId, uint256 exprWithNotVarId) =
            expressionContract.splitExpression(pos.expressionId, variable);

        uint256 positionWithVarId = _registerPosition(collateralToken, exprWithVarId);
        uint256 positionWithNotVarId = _registerPosition(collateralToken, exprWithNotVarId);

        // Burn the original position tokens
        _burn(msg.sender, positionId, userBalance);

        // Mint new position tokens
        _mint(msg.sender, positionWithVarId, userBalance, "");
        _mint(msg.sender, positionWithNotVarId, userBalance, "");
    }

    /**
     * @notice Splits a position by extracting a specific conjunction
     * @param positionId The ID of the position to split
     * @param conjunctionIndex The index of the conjunction to extract
     */
    function splitPositionByConjunction(uint256 positionId, uint256 conjunctionIndex) external nonReentrant {
        uint256 userBalance = balanceOf(msg.sender, positionId);
        if (userBalance == 0) revert NoBalanceToSplit();

        Position storage pos = positions[positionId];
        IERC20 collateralToken = pos.collateralToken;
        if (collateralToken == IERC20(address(0))) revert PositionNotFound();

        // Split the expression into two expressions. The conjunctions of an expression are exclusive,
        // so the two parts add up to the original.
        (uint256 singleConjExprId, uint256 remainingExprId) =
            expressionContract.splitConjunction(pos.expressionId, conjunctionIndex);

        uint256 positionSingleConjId = _registerPosition(collateralToken, singleConjExprId);
        uint256 positionRemainingId = _registerPosition(collateralToken, remainingExprId);

        // Burn the original position tokens
        _burn(msg.sender, positionId, userBalance);

        // Mint new position tokens
        _mint(msg.sender, positionSingleConjId, userBalance, "");
        _mint(msg.sender, positionRemainingId, userBalance, "");
    }

    /**
     * @notice Merges two positions conditioned on a variable and its negation into a single position
     * @dev Moves the smaller of the two balances: that amount is burnt from each side and minted once as
     *      the merged position. Any remainder stays where it was.
     * @param positionWithVarId The ID of the position conditioned on Var
     * @param positionWithNotVarId The ID of the position conditioned on ¬Var
     * @param variable The variable used in the conditioning
     */
    function mergePositionsOnVariable(uint256 positionWithVarId, uint256 positionWithNotVarId, uint256 variable)
        external
        nonReentrant
    {
        if (positionWithVarId == positionWithNotVarId) revert SamePosition();

        uint256 userBalanceVar = balanceOf(msg.sender, positionWithVarId);
        uint256 userBalanceNotVar = balanceOf(msg.sender, positionWithNotVarId);
        if (userBalanceVar == 0 || userBalanceNotVar == 0) revert NoBalanceToMerge();

        Position storage posVar = positions[positionWithVarId];
        Position storage posNotVar = positions[positionWithNotVarId];
        IERC20 collateralToken = posVar.collateralToken;

        // Ensure collateral tokens are the same
        if (collateralToken != posNotVar.collateralToken) revert CollateralMismatch();

        // Merge expressions conditioned on variable and its negation
        uint256 mergedExprId =
            expressionContract.mergeExpressionsOnVariable(posVar.expressionId, posNotVar.expressionId, variable);

        _mergeInto(
            positionWithVarId, positionWithNotVarId, userBalanceVar, userBalanceNotVar, collateralToken, mergedExprId
        );
    }

    /**
     * @notice Merges two positions that cannot both pay into one position on their OR
     * @dev Reverts (ExpressionsOverlap) if the two expressions can be true together. Moves the smaller of
     *      the two balances, like mergePositionsOnVariable.
     * @param positionId1 The ID of the first position
     * @param positionId2 The ID of the second position
     */
    function mergePositions(uint256 positionId1, uint256 positionId2) external nonReentrant {
        if (positionId1 == positionId2) revert SamePosition();

        uint256 userBalance1 = balanceOf(msg.sender, positionId1);
        uint256 userBalance2 = balanceOf(msg.sender, positionId2);
        if (userBalance1 == 0 || userBalance2 == 0) revert NoBalanceToMerge();

        Position storage pos1 = positions[positionId1];
        Position storage pos2 = positions[positionId2];
        IERC20 collateralToken = pos1.collateralToken;

        // Ensure collateral tokens are the same
        if (collateralToken != pos2.collateralToken) revert CollateralMismatch();

        // Attempt to merge expressions
        uint256 mergedExprId = expressionContract.mergeExpressions(pos1.expressionId, pos2.expressionId);

        _mergeInto(positionId1, positionId2, userBalance1, userBalance2, collateralToken, mergedExprId);
    }

    /**
     * @notice Evaluates a position's value and caches the result
     */
    function evaluatePosition(uint256 positionId) external nonReentrant returns (uint256 value, bool isComplete) {
        return _evaluatePosition(positionId);
    }

    function _evaluatePosition(uint256 positionId) private returns (uint256 value, bool isComplete) {
        Position storage pos = positions[positionId];
        if (pos.collateralToken == IERC20(address(0))) revert PositionNotFound();

        // Get variable IDs from the expression
        uint256[] memory variables = expressionContract.getExpressionVariables(pos.expressionId);
        uint256[] memory variableValues = new uint256[](variables.length);

        // Check if all events are settled
        for (uint256 i = 0; i < variables.length; i++) {
            (bool settled, uint256 outcome,,) = eventContract.getEventOutcome(variables[i]);
            if (!settled) {
                revert EventsNotSettled();
            }
            variableValues[i] = outcome;
        }

        // Evaluate the expression
        value = expressionContract.evaluateExpressionWithValues(pos.expressionId, variables, variableValues);
        pos.evaluatedValue = value;
        pos.evaluationTime = block.timestamp;
        emit PositionEvaluated(positionId, pos.expressionId, value, block.timestamp);
        return (value, true);
    }

    /**
     * @notice Partially evaluates a position based on a settled variable
     * @dev The settled value is read from EventContract; the event must be settled. With value v, a balance
     *      b becomes b * v of the position with the variable true and b * (1 - v) of the position with it
     *      false, both rounded down.
     * @param positionId The ID of the position to evaluate
     * @param variableId The settled variable ID
     */
    function partialEvaluatePosition(uint256 positionId, uint256 variableId) external nonReentrant {
        uint256 userBalance = balanceOf(msg.sender, positionId);
        if (userBalance == 0) revert NoBalanceToEvaluate();

        Position storage pos = positions[positionId];
        IERC20 collateralToken = pos.collateralToken;
        if (collateralToken == IERC20(address(0))) revert PositionNotFound();

        // The value comes from the event contract, never from the caller
        (bool settled, uint256 settledValue,,) = eventContract.getEventOutcome(variableId);
        if (!settled) revert EventsNotSettled();

        // Split the position into two: one assuming Var is true, one assuming Var is false
        uint256[] memory variableIds = new uint256[](1);
        variableIds[0] = variableId;

        uint256[] memory variableValuesTrue = new uint256[](1);
        variableValuesTrue[0] = SCALE; // Set the value for 'true'

        uint256[] memory variableValuesFalse = new uint256[](1);
        variableValuesFalse[0] = 0; // Set the value for 'false'

        // Simplify expressions assuming Var = true and Var = false
        uint256 simplifiedExprIdTrue =
            expressionContract.simplifyExpression(pos.expressionId, variableIds, variableValuesTrue);
        uint256 simplifiedExprIdFalse =
            expressionContract.simplifyExpression(pos.expressionId, variableIds, variableValuesFalse);

        // The expression does not depend on this variable: nothing to do
        if (simplifiedExprIdTrue == pos.expressionId && simplifiedExprIdFalse == pos.expressionId) return;

        // Calculate adjusted token amounts based on the settled value, each rounded down
        uint256 amountTrue = (userBalance * settledValue) / SCALE;
        uint256 amountFalse = (userBalance * (SCALE - settledValue)) / SCALE;

        uint256 positionTrueId = _registerPosition(collateralToken, simplifiedExprIdTrue);
        uint256 positionFalseId = _registerPosition(collateralToken, simplifiedExprIdFalse);

        // Burn the original position tokens
        _burn(msg.sender, positionId, userBalance);

        // Mint new position tokens with adjusted amounts
        if (amountTrue > 0) {
            _mint(msg.sender, positionTrueId, amountTrue, "");
        }
        if (amountFalse > 0) {
            _mint(msg.sender, positionFalseId, amountFalse, "");
        }

        emit PositionPartiallyEvaluated(positionId, variableId, settledValue, block.timestamp);
    }

    /**
     * @notice Redeems a position for collateral using continuous payout
     */
    function redeemPosition(uint256 positionId, uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();

        uint256 balance = balanceOf(msg.sender, positionId);
        if (balance < amount) revert NoBalanceToRedeem();

        Position storage pos = positions[positionId];
        if (pos.collateralToken == IERC20(address(0))) revert PositionNotFound();

        uint256 value;

        // Get evaluation result
        if (pos.evaluationTime == 0) {
            // Not evaluated yet
            bool isComplete;
            (value, isComplete) = _evaluatePosition(positionId);

            if (!isComplete) revert EventsNotSettled();
        } else {
            value = pos.evaluatedValue;
        }

        // Calculate payout based on continuous value, rounded down
        uint256 payout = (amount * value) / SCALE;

        // Update state
        _burn(msg.sender, positionId, amount);

        // Transfer collateral
        if (payout > 0) {
            pos.collateralToken.safeTransfer(msg.sender, payout);
        }

        emit PositionRedeemed(positionId, pos.expressionId, address(pos.collateralToken), amount, payout);
    }

    /**
     * @notice Gets cached position evaluation if available
     */
    function getPositionValue(uint256 positionId)
        external
        view
        returns (uint256 value, uint256 timestamp, bool isEvaluated)
    {
        Position storage pos = positions[positionId];
        return (pos.evaluatedValue, pos.evaluationTime, pos.evaluationTime != 0);
    }

    /**
     * @notice Burns the smaller balance from both positions and mints it once as the merged position
     */
    function _mergeInto(
        uint256 positionId1,
        uint256 positionId2,
        uint256 balance1,
        uint256 balance2,
        IERC20 collateralToken,
        uint256 mergedExprId
    ) private {
        uint256 amount = balance1 < balance2 ? balance1 : balance2;
        uint256 mergedPositionId = _registerPosition(collateralToken, mergedExprId);

        _burn(msg.sender, positionId1, amount);
        _burn(msg.sender, positionId2, amount);
        _mint(msg.sender, mergedPositionId, amount, "");
    }

    /**
     * @notice Records the collateral and expression of a position the first time it is used
     */
    function _registerPosition(IERC20 collateralToken, uint256 expressionId) private returns (uint256 positionId) {
        positionId = getPositionId(collateralToken, expressionId);
        Position storage pos = positions[positionId];
        if (pos.collateralToken == IERC20(address(0))) {
            pos.collateralToken = collateralToken;
            pos.expressionId = expressionId;
        }
    }
}
