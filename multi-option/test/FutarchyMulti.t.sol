// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {IConditionalTokens, IERC20, IRealityETH_v3_0, IWrapped1155Factory} from "../src/Interfaces.sol";
import {FutarchyMultiFactory} from "../src/FutarchyMultiFactory.sol";
import {FutarchyMultiProposal} from "../src/FutarchyMultiProposal.sol";
import {FutarchyMultiRealityProxy} from "../src/FutarchyMultiRealityProxy.sol";
import {FutarchyMultiRouter, IProposalRegistry} from "../src/FutarchyMultiRouter.sol";

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _symbol, uint8 _decimals) {
        name = _symbol;
        symbol = _symbol;
        decimals = _decimals;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

/// A made-up proposal that copies a real one's answers, as an attacker would deploy.
contract FakeProposal {
    FutarchyMultiProposal immutable real;
    IERC20 immutable collateral;

    constructor(FutarchyMultiProposal _real, IERC20 _collateral) {
        real = _real;
        collateral = _collateral;
    }

    function numOutcomes() external view returns (uint256) {
        return real.numOutcomes();
    }

    function collateralIndex(IERC20) external pure returns (uint256) {
        return 1;
    }

    function parentCollectionId() external pure returns (bytes32) {
        return bytes32(0);
    }

    function conditionId() external view returns (bytes32) {
        return real.conditionId();
    }

    function wrappedOutcome(uint256 index) external view returns (IERC20, bytes memory) {
        return real.wrappedOutcome(index);
    }
}

/// Runs against the same ConditionalTokens, Wrapped1155Factory and Reality.eth v3 bytecode that is
/// deployed on Robinhood Chain (creation code read from ./bytecode).
contract FutarchyMultiTest is Test {
    uint32 constant TIMEOUT = 302_400;
    uint256 constant MIN_BOND = 0.05 ether;
    address constant ARBITRATOR = address(0xA4B1);
    address constant ALICE = address(0xA11CE);

    IConditionalTokens ct;
    IWrapped1155Factory w1155;
    IRealityETH_v3_0 reality;
    FutarchyMultiRealityProxy proxy;
    FutarchyMultiFactory factory;
    FutarchyMultiRouter router;
    MockERC20 nvda;
    MockERC20 usdg;

    uint256 constant N = 7;
    uint256 constant OTHER = 6;

    function deployHex(string memory path) internal returns (address addr) {
        bytes memory code = vm.parseBytes(vm.readFile(path));
        assembly {
            addr := create(0, add(code, 0x20), mload(code))
        }
        require(addr != address(0), "deploy failed");
    }

    function setUp() public {
        vm.warp(1_800_000_000);
        ct = IConditionalTokens(deployHex("bytecode/ctf.hex"));
        w1155 = IWrapped1155Factory(deployHex("bytecode/w1155.hex"));
        reality = IRealityETH_v3_0(deployHex("bytecode/reality.hex"));
        proxy = new FutarchyMultiRealityProxy(ct, reality);
        factory = new FutarchyMultiFactory(ARBITRATOR, reality, w1155, ct, proxy, TIMEOUT);
        router = new FutarchyMultiRouter(ct, w1155, IProposalRegistry(address(factory)));
        nvda = new MockERC20("NVDA", 18);
        usdg = new MockERC20("USDG", 6);
        nvda.mint(ALICE, 10 ether);
        usdg.mint(ALICE, 1_000e6);
        vm.deal(ALICE, 10 ether);
    }

    function topParams() internal view returns (FutarchyMultiFactory.CreateProposalParams memory p) {
        p.marketName = "Who will be the first individual officially announced as the next CEO of NVIDIA?";
        p.outcomes = new string[](N);
        p.outcomes[0] = "Ian Buck";
        p.outcomes[1] = "Rene Haas";
        p.outcomes[2] = "Johny Srouji";
        p.outcomes[3] = "Colette Kress";
        p.outcomes[4] = "Tim Cook";
        p.outcomes[5] = "Jensen Huang (No Change)";
        p.outcomes[6] = "Other";
        p.outcomeSymbols = new string[](N);
        p.outcomeSymbols[0] = "BUCK";
        p.outcomeSymbols[1] = "HAAS";
        p.outcomeSymbols[2] = "SROUJI";
        p.outcomeSymbols[3] = "KRESS";
        p.outcomeSymbols[4] = "COOK";
        p.outcomeSymbols[5] = "NOCHANGE";
        p.outcomeSymbols[6] = "OTHER";
        p.collateralToken1 = IERC20(address(nvda));
        p.collateralToken2 = IERC20(address(usdg));
        p.category = "business";
        p.lang = "en";
        p.minBond = MIN_BOND;
        p.openingTime = uint32(block.timestamp);
    }

    function childParams(address parent) internal view returns (FutarchyMultiFactory.CreateProposalParams memory p) {
        p = topParams();
        p.marketName = "If the next CEO of NVIDIA is not one of the first list, who is it?";
        p.outcomes = new string[](3);
        p.outcomes[0] = "Lisa Su";
        p.outcomes[1] = "Jay Puri";
        p.outcomes[2] = "Other";
        p.outcomeSymbols = new string[](3);
        p.outcomeSymbols[0] = "SU";
        p.outcomeSymbols[1] = "PURI";
        p.outcomeSymbols[2] = "OTHER2";
        p.parentMarket = parent;
        p.parentOutcome = OTHER;
    }

    function token(FutarchyMultiProposal p, MockERC20 collateral, uint256 outcome) internal view returns (IERC20 t) {
        (t,) = p.wrappedOutcomeFor(IERC20(address(collateral)), outcome);
    }

    function split(FutarchyMultiProposal p, MockERC20 collateral, uint256 amount) internal {
        vm.startPrank(ALICE);
        (IERC20 parentToken,) = p.parentWrappedOutcome(IERC20(address(collateral)));
        if (address(parentToken) == address(0)) collateral.approve(address(router), amount);
        else parentToken.approve(address(router), amount);
        router.splitPosition(p, IERC20(address(collateral)), amount);
        vm.stopPrank();
    }

    function merge(FutarchyMultiProposal p, MockERC20 collateral, uint256 amount) internal {
        vm.startPrank(ALICE);
        for (uint256 i = 0; i < p.numOutcomes(); i++) {
            token(p, collateral, i).approve(address(router), amount);
        }
        router.mergePositions(p, IERC20(address(collateral)), amount);
        vm.stopPrank();
    }

    function redeem(FutarchyMultiProposal p, MockERC20 collateral, uint256 outcome, uint256 amount) internal {
        vm.startPrank(ALICE);
        token(p, collateral, outcome).approve(address(router), amount);
        router.redeemPositions(p, IERC20(address(collateral)), outcome, amount);
        vm.stopPrank();
    }

    function answerAndFinalize(FutarchyMultiProposal p, bytes32 answer) internal {
        vm.prank(ALICE);
        reality.submitAnswer{value: MIN_BOND}(p.questionId(), answer, 0);
        vm.warp(block.timestamp + TIMEOUT + 1);
        proxy.resolve(p);
    }

    function test_create_tokensHaveCollateralDecimalsAndNames() public {
        FutarchyMultiProposal p = FutarchyMultiProposal(factory.createProposal(topParams()));
        assertEq(p.numOutcomes(), N);
        assertEq(ct.getOutcomeSlotCount(p.conditionId()), N);
        assertTrue(factory.isProposal(address(p)));
        assertEq(token(p, nvda, 0).symbol(), "BUCK_NVDA");
        assertEq(token(p, usdg, 6).symbol(), "OTHER_USDG");
        assertEq(token(p, nvda, 3).decimals(), 18);
        assertEq(token(p, usdg, 3).decimals(), 6);
        assertEq(
            p.encodedQuestion(),
            unicode"Who will be the first individual officially announced as the next CEO of NVIDIA?␟\"Ian Buck\",\"Rene Haas\",\"Johny Srouji\",\"Colette Kress\",\"Tim Cook\",\"Jensen Huang (No Change)\",\"Other\"␟business␟en"
        );
    }

    function test_splitAndMerge_bothCollaterals() public {
        FutarchyMultiProposal p = FutarchyMultiProposal(factory.createProposal(topParams()));
        split(p, nvda, 2 ether);
        split(p, usdg, 300e6);
        assertEq(nvda.balanceOf(ALICE), 8 ether);
        assertEq(usdg.balanceOf(ALICE), 700e6);
        for (uint256 i = 0; i < N; i++) {
            assertEq(token(p, nvda, i).balanceOf(ALICE), 2 ether);
            assertEq(token(p, usdg, i).balanceOf(ALICE), 300e6);
        }
        merge(p, nvda, 2 ether);
        merge(p, usdg, 300e6);
        assertEq(nvda.balanceOf(ALICE), 10 ether);
        assertEq(usdg.balanceOf(ALICE), 1_000e6);
        assertEq(token(p, nvda, 0).balanceOf(ALICE), 0);
        assertEq(nvda.balanceOf(address(router)), 0);
        assertEq(usdg.balanceOf(address(router)), 0);
    }

    function test_splitOtherIntoNewCandidates_andMergeBack() public {
        FutarchyMultiProposal a = FutarchyMultiProposal(factory.createProposal(topParams()));
        split(a, nvda, 1 ether);
        split(a, usdg, 100e6);

        FutarchyMultiProposal b = FutarchyMultiProposal(factory.createProposal(childParams(address(a))));
        assertEq(b.parentMarket(), address(a));
        assertEq(token(b, usdg, 0).symbol(), "SU_USDG");

        split(b, nvda, 1 ether);
        split(b, usdg, 100e6);
        // "Other" is consumed; the named options of the first list are untouched.
        assertEq(token(a, nvda, OTHER).balanceOf(ALICE), 0);
        assertEq(token(a, usdg, OTHER).balanceOf(ALICE), 0);
        assertEq(token(a, nvda, 0).balanceOf(ALICE), 1 ether);
        for (uint256 i = 0; i < 3; i++) {
            assertEq(token(b, nvda, i).balanceOf(ALICE), 1 ether);
            assertEq(token(b, usdg, i).balanceOf(ALICE), 100e6);
        }

        merge(b, usdg, 40e6);
        assertEq(token(a, usdg, OTHER).balanceOf(ALICE), 40e6);
        assertEq(token(b, usdg, 2).balanceOf(ALICE), 60e6);
    }

    function test_laterAddedCandidateWins_redeemsThroughBothLevels() public {
        FutarchyMultiProposal a = FutarchyMultiProposal(factory.createProposal(topParams()));
        FutarchyMultiProposal b = FutarchyMultiProposal(factory.createProposal(childParams(address(a))));
        split(a, nvda, 1 ether);
        split(a, usdg, 100e6);
        split(b, nvda, 1 ether);
        split(b, usdg, 100e6);

        // Lisa Su (added later) is announced: the first question resolves Other, the second Su.
        answerAndFinalize(a, bytes32(OTHER));
        answerAndFinalize(b, bytes32(uint256(0)));

        redeem(b, nvda, 0, 1 ether);
        redeem(b, usdg, 0, 100e6);
        assertEq(token(a, nvda, OTHER).balanceOf(ALICE), 1 ether);
        assertEq(token(a, usdg, OTHER).balanceOf(ALICE), 100e6);

        redeem(a, nvda, OTHER, 1 ether);
        redeem(a, usdg, OTHER, 100e6);
        assertEq(nvda.balanceOf(ALICE), 10 ether);
        assertEq(usdg.balanceOf(ALICE), 1_000e6);

        // Losers pay nothing: a named option of the first list, and a losing option of the second.
        redeem(a, usdg, 0, 100e6);
        redeem(b, usdg, 1, 100e6);
        assertEq(usdg.balanceOf(ALICE), 1_000e6);
        assertEq(token(a, usdg, OTHER).balanceOf(ALICE), 0);
    }

    function test_namedCandidateWins_childTokensAreWorthless() public {
        FutarchyMultiProposal a = FutarchyMultiProposal(factory.createProposal(topParams()));
        FutarchyMultiProposal b = FutarchyMultiProposal(factory.createProposal(childParams(address(a))));
        split(a, usdg, 100e6);
        split(b, usdg, 100e6);

        answerAndFinalize(a, bytes32(uint256(1))); // Rene Haas
        redeem(a, usdg, 1, 100e6);
        assertEq(usdg.balanceOf(ALICE), 1_000e6);

        // Whatever the second question says, its tokens only ever redeem into "Other", which lost.
        answerAndFinalize(b, bytes32(uint256(2)));
        redeem(b, usdg, 2, 100e6);
        assertEq(token(a, usdg, OTHER).balanceOf(ALICE), 100e6);
        redeem(a, usdg, OTHER, 100e6);
        assertEq(usdg.balanceOf(ALICE), 1_000e6);
    }

    function test_invalidOrOutOfRangeAnswer_paysOther() public {
        FutarchyMultiProposal a = FutarchyMultiProposal(factory.createProposal(topParams()));
        split(a, usdg, 50e6);
        answerAndFinalize(a, bytes32(type(uint256).max)); // Reality.eth "invalid"
        assertEq(ct.payoutNumerators(a.conditionId(), OTHER), 1);
        assertEq(ct.payoutNumerators(a.conditionId(), 0), 0);
        redeem(a, usdg, OTHER, 50e6);
        assertEq(usdg.balanceOf(ALICE), 1_000e6);

        FutarchyMultiFactory.CreateProposalParams memory p = topParams();
        p.marketName = "second market";
        FutarchyMultiProposal c = FutarchyMultiProposal(factory.createProposal(p));
        answerAndFinalize(c, bytes32(uint256(99)));
        assertEq(ct.payoutNumerators(c.conditionId(), OTHER), 1);
    }

    function test_resolveBeforeFinal_reverts() public {
        FutarchyMultiProposal a = FutarchyMultiProposal(factory.createProposal(topParams()));
        vm.expectRevert();
        proxy.resolve(a);
        vm.prank(ALICE);
        reality.submitAnswer{value: MIN_BOND}(a.questionId(), bytes32(uint256(0)), 0);
        vm.expectRevert();
        proxy.resolve(a);
    }

    function test_createValidation() public {
        FutarchyMultiProposal a = FutarchyMultiProposal(factory.createProposal(topParams()));

        FutarchyMultiFactory.CreateProposalParams memory p = childParams(address(0xdead));
        vm.expectRevert("parent is not a proposal of this factory");
        factory.createProposal(p);

        p = childParams(address(a));
        p.parentOutcome = N;
        vm.expectRevert("parent option out of range");
        factory.createProposal(p);

        p = childParams(address(a));
        p.collateralToken2 = IERC20(address(new MockERC20("DAI", 18)));
        vm.expectRevert("collaterals must match the parent");
        factory.createProposal(p);

        p = topParams();
        p.outcomeSymbols = new string[](2);
        vm.expectRevert("one symbol per option");
        factory.createProposal(p);

        p = topParams();
        p.marketName = "another question";
        p.outcomeSymbols[0] = "A_SYMBOL_THAT_IS_FAR_TOO_LONG_FOR_IT";
        vm.expectRevert("token name too long");
        factory.createProposal(p);
    }

    function test_router_rejectsForeignCollateral() public {
        FutarchyMultiProposal a = FutarchyMultiProposal(factory.createProposal(topParams()));
        MockERC20 dai = new MockERC20("DAI", 18);
        vm.expectRevert("not a collateral of this proposal");
        router.splitPosition(a, IERC20(address(dai)), 1);
    }

    function test_create_rejectsTextThatWouldChangeTheQuestion() public {
        FutarchyMultiFactory.CreateProposalParams memory p = topParams();
        p.outcomes[0] = 'Yes","No'; // would show three options for a two-option condition
        vm.expectRevert("text has a forbidden character");
        factory.createProposal(p);

        p = topParams();
        p.marketName = 'Who is "next"?';
        vm.expectRevert("text has a forbidden character");
        factory.createProposal(p);

        p = topParams();
        p.outcomes[1] = "Rene\\Haas";
        vm.expectRevert("text has a forbidden character");
        factory.createProposal(p);

        p = topParams();
        p.category = "business\nx";
        vm.expectRevert("text has a forbidden character");
        factory.createProposal(p);

        p = topParams();
        p.outcomes[2] = unicode"Johny␟Srouji";
        vm.expectRevert("text has the field separator");
        factory.createProposal(p);

        // Other non-ASCII text is fine.
        p = topParams();
        p.outcomes[2] = unicode"José Müller – 黄";
        factory.createProposal(p);
    }

    function test_create_rejectsSecondMarketOnTheSameQuestion() public {
        factory.createProposal(topParams());
        FutarchyMultiFactory.CreateProposalParams memory p = topParams();
        p.outcomeSymbols[0] = "BUCK2"; // same question, different token names
        vm.expectRevert("a market already exists for this question");
        factory.createProposal(p);
    }

    function test_router_rejectsProposalNotFromFactory() public {
        FutarchyMultiProposal real = FutarchyMultiProposal(factory.createProposal(topParams()));
        split(real, usdg, 10e6);
        // Tokens sent to the router by mistake must not be reachable through a made-up proposal.
        IERC20 stray = token(real, usdg, 0);
        vm.prank(ALICE);
        stray.transfer(address(router), 10e6);

        FakeProposal fake = new FakeProposal(real, IERC20(address(usdg)));
        vm.expectRevert("unknown proposal");
        router.splitPosition(FutarchyMultiProposal(address(fake)), IERC20(address(usdg)), 1);
        vm.expectRevert("unknown proposal");
        router.mergePositions(FutarchyMultiProposal(address(fake)), IERC20(address(usdg)), 1);
        vm.expectRevert("unknown proposal");
        router.redeemPositions(FutarchyMultiProposal(address(fake)), IERC20(address(usdg)), 0, 1);
        assertEq(token(real, usdg, 0).balanceOf(address(router)), 10e6);
    }

    function test_sixteenOptions_createSplitMergeFitInABlock() public {
        FutarchyMultiFactory.CreateProposalParams memory p = topParams();
        p.marketName = "sixteen";
        p.outcomes = new string[](16);
        p.outcomeSymbols = new string[](16);
        for (uint256 i = 0; i < 16; i++) {
            p.outcomes[i] = string(abi.encodePacked("Option ", vm.toString(i)));
            p.outcomeSymbols[i] = string(abi.encodePacked("OPT", vm.toString(i)));
        }
        uint256 g = gasleft();
        FutarchyMultiProposal m = FutarchyMultiProposal(factory.createProposal(p));
        uint256 createGas = g - gasleft();
        g = gasleft();
        split(m, usdg, 1e6);
        uint256 splitGas = g - gasleft();
        merge(m, usdg, 1e6);
        emit log_named_uint("create gas, 16 options", createGas);
        emit log_named_uint("split gas, 16 options", splitGas);
        assertLt(createGas, 16_000_000);
        assertLt(splitGas, 6_000_000);
        assertEq(usdg.balanceOf(ALICE), 1_000e6);

        p.outcomes = new string[](17);
        p.outcomeSymbols = new string[](17);
        vm.expectRevert("2 to 16 options");
        factory.createProposal(p);
    }

    function test_threeLevels_otherSplitTwice() public {
        FutarchyMultiProposal a = FutarchyMultiProposal(factory.createProposal(topParams()));
        FutarchyMultiProposal b = FutarchyMultiProposal(factory.createProposal(childParams(address(a))));
        FutarchyMultiFactory.CreateProposalParams memory p = childParams(address(b));
        p.marketName = "third list";
        p.parentOutcome = 2; // OTHER2
        p.outcomes[0] = "Hock Tan";
        p.outcomeSymbols[0] = "TAN";
        p.outcomeSymbols[2] = "OTHER3";
        FutarchyMultiProposal c = FutarchyMultiProposal(factory.createProposal(p));

        split(a, usdg, 10e6);
        split(b, usdg, 10e6);
        split(c, usdg, 10e6);
        assertEq(token(c, usdg, 0).symbol(), "TAN_USDG");
        assertEq(token(c, usdg, 0).balanceOf(ALICE), 10e6);

        answerAndFinalize(a, bytes32(OTHER));
        answerAndFinalize(b, bytes32(uint256(2)));
        answerAndFinalize(c, bytes32(uint256(0)));
        redeem(c, usdg, 0, 10e6);
        redeem(b, usdg, 2, 10e6);
        redeem(a, usdg, OTHER, 10e6);
        assertEq(usdg.balanceOf(ALICE), 1_000e6);
    }
}
