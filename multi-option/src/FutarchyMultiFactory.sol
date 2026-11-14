// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IConditionalTokens, IERC20, IRealityETH_v3_0, IWrapped1155Factory} from "./Interfaces.sol";
import {FutarchyMultiProposal} from "./FutarchyMultiProposal.sol";
import {FutarchyMultiRealityProxy} from "./FutarchyMultiRealityProxy.sol";

/// @notice Creates multi-option futarchy markets. Adapted from Seer's FutarchyFactory (two options).
/// For N options it asks one single-select Reality.eth question, prepares one N-slot condition and
/// deploys 2N wrapped outcome tokens (N per collateral), each with its collateral's decimals.
contract FutarchyMultiFactory {
    struct CreateProposalParams {
        string marketName;
        /// Option names shown to Reality.eth answerers, for example "Ian Buck". No double quotes.
        /// The last option must be the catch-all ("Other"): invalid answers pay it.
        string[] outcomes;
        /// Short symbols for token names, for example "BUCK". Token name is SYMBOL_COLLATERAL.
        string[] outcomeSymbols;
        IERC20 collateralToken1;
        IERC20 collateralToken2;
        string category;
        string lang;
        uint256 minBond;
        uint32 openingTime;
        /// Optional: a proposal of this factory whose option `parentOutcome` this market divides.
        address parentMarket;
        uint256 parentOutcome;
    }

    uint8 internal constant REALITY_SINGLE_SELECT_TEMPLATE = 2;
    uint256 public constant MAX_OUTCOMES = 32;

    uint32 public immutable questionTimeout;
    address public immutable arbitrator;
    IRealityETH_v3_0 public immutable realitio;
    IWrapped1155Factory public immutable wrapped1155Factory;
    IConditionalTokens public immutable conditionalTokens;
    FutarchyMultiRealityProxy public immutable realityProxy;

    address[] public proposals;
    mapping(address => bool) public isProposal;

    event NewMultiProposal(
        address indexed proposal,
        string marketName,
        bytes32 conditionId,
        bytes32 questionId,
        address indexed parentMarket,
        uint256 parentOutcome
    );

    constructor(
        address _arbitrator,
        IRealityETH_v3_0 _realitio,
        IWrapped1155Factory _wrapped1155Factory,
        IConditionalTokens _conditionalTokens,
        FutarchyMultiRealityProxy _realityProxy,
        uint32 _questionTimeout
    ) {
        arbitrator = _arbitrator;
        realitio = _realitio;
        wrapped1155Factory = _wrapped1155Factory;
        conditionalTokens = _conditionalTokens;
        realityProxy = _realityProxy;
        questionTimeout = _questionTimeout;
    }

    function createProposal(CreateProposalParams memory p) external returns (address) {
        uint256 n = p.outcomes.length;
        require(n >= 2 && n <= MAX_OUTCOMES, "2 to 32 options");
        require(p.outcomeSymbols.length == n, "one symbol per option");
        require(address(p.collateralToken1) != address(p.collateralToken2), "collaterals must differ");

        FutarchyMultiProposal.Params memory params;
        params.collateralToken1 = p.collateralToken1;
        params.collateralToken2 = p.collateralToken2;

        if (p.parentMarket != address(0)) {
            require(isProposal[p.parentMarket], "parent is not a proposal of this factory");
            FutarchyMultiProposal parent = FutarchyMultiProposal(p.parentMarket);
            require(p.parentOutcome < parent.numOutcomes(), "parent option out of range");
            require(
                parent.collateralToken1() == p.collateralToken1 && parent.collateralToken2() == p.collateralToken2,
                "collaterals must match the parent"
            );
            params.parentMarket = p.parentMarket;
            params.parentOutcome = p.parentOutcome;
            params.parentCollectionId = conditionalTokens.getCollectionId(
                parent.parentCollectionId(), parent.conditionId(), 1 << p.parentOutcome
            );
        }

        params.encodedQuestion = encodeRealityQuestion(p.marketName, p.outcomes, p.category, p.lang);
        params.questionId = askRealityQuestion(params.encodedQuestion, p.openingTime, p.minBond);
        params.conditionId = prepareCondition(params.questionId, n);

        (IERC20[] memory wrapped, bytes[] memory data) = deployERC20Positions(params, p.outcomeSymbols);

        FutarchyMultiProposal instance = new FutarchyMultiProposal(
            p.marketName, p.outcomes, p.outcomeSymbols, params, wrapped, data, realityProxy
        );

        proposals.push(address(instance));
        isProposal[address(instance)] = true;

        emit NewMultiProposal(
            address(instance), p.marketName, params.conditionId, params.questionId, p.parentMarket, p.parentOutcome
        );

        return address(instance);
    }

    /// @dev Reality.eth single-select format: question ␟ "A","B",... ␟ category ␟ lang.
    function encodeRealityQuestion(
        string memory question,
        string[] memory outcomes,
        string memory category,
        string memory lang
    ) public pure returns (string memory) {
        bytes memory separator = abi.encodePacked(unicode"␟");
        bytes memory list;
        for (uint256 i = 0; i < outcomes.length; i++) {
            require(bytes(outcomes[i]).length != 0, "empty option name");
            list = abi.encodePacked(list, i == 0 ? "" : ",", '"', outcomes[i], '"');
        }
        return string(abi.encodePacked(question, separator, list, separator, category, separator, lang));
    }

    function askRealityQuestion(string memory encodedQuestion, uint32 openingTime, uint256 minBond)
        internal
        returns (bytes32)
    {
        bytes32 contentHash =
            keccak256(abi.encodePacked(uint256(REALITY_SINGLE_SELECT_TEMPLATE), openingTime, encodedQuestion));
        bytes32 questionId = keccak256(
            abi.encodePacked(
                contentHash, arbitrator, questionTimeout, minBond, address(realitio), address(this), uint256(0)
            )
        );

        if (realitio.getTimeout(questionId) != 0) {
            // The question already exists.
            return questionId;
        }

        return realitio.askQuestionWithMinBond(
            REALITY_SINGLE_SELECT_TEMPLATE, encodedQuestion, arbitrator, questionTimeout, openingTime, 0, minBond
        );
    }

    function prepareCondition(bytes32 questionId, uint256 outcomeSlotCount) internal returns (bytes32 conditionId) {
        conditionId = conditionalTokens.getConditionId(address(realityProxy), questionId, outcomeSlotCount);
        if (conditionalTokens.getOutcomeSlotCount(conditionId) == 0) {
            conditionalTokens.prepareCondition(address(realityProxy), questionId, outcomeSlotCount);
        }
    }

    function deployERC20Positions(FutarchyMultiProposal.Params memory params, string[] memory symbols)
        internal
        returns (IERC20[] memory wrapped, bytes[] memory data)
    {
        uint256 n = symbols.length;
        wrapped = new IERC20[](2 * n);
        data = new bytes[](2 * n);

        for (uint256 c = 0; c < 2; c++) {
            IERC20 collateral = c == 0 ? params.collateralToken1 : params.collateralToken2;
            string memory collateralSymbol = collateral.symbol();
            // Outcome tokens use the decimals of their collateral.
            uint8 decimals = collateral.decimals();

            for (uint256 i = 0; i < n; i++) {
                require(bytes(symbols[i]).length != 0, "empty option symbol");
                bytes32 collectionId =
                    conditionalTokens.getCollectionId(params.parentCollectionId, params.conditionId, 1 << i);
                uint256 tokenId = conditionalTokens.getPositionId(address(collateral), collectionId);

                bytes32 name = toString31(string(abi.encodePacked(symbols[i], "_", collateralSymbol)));
                bytes memory tokenData = abi.encodePacked(name, name, decimals);

                wrapped[c * n + i] =
                    wrapped1155Factory.requireWrapped1155(address(conditionalTokens), tokenId, tokenData);
                data[c * n + i] = tokenData;
            }
        }
    }

    /// @dev Encodes a string shorter than 32 bytes the way Solidity stores short strings.
    /// See https://github.com/gnosis/1155-to-20/pull/4#discussion_r573630922
    function toString31(string memory value) internal pure returns (bytes32 encodedString) {
        uint256 length = bytes(value).length;
        require(length < 32, "token name too long");

        assembly {
            encodedString := mload(add(value, 0x20))
        }

        bytes32 mask = bytes32(type(uint256).max << ((32 - length) << 3));
        encodedString = encodedString & mask;
        encodedString = encodedString | bytes32(length << 1);
    }

    function allMarkets() external view returns (address[] memory) {
        return proposals;
    }

    function marketsCount() external view returns (uint256) {
        return proposals.length;
    }
}
