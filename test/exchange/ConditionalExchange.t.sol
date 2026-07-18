// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { ConditionalExchange } from "../../src/exchange/ConditionalExchange.sol";
import { ORDER_TYPEHASH, Order, OrderStatus, Side, SignatureType } from "../../src/exchange/libraries/OrderStructs.sol";
import { PairRegistry } from "../../src/exchange/mixins/PairRegistry.sol";
import { Signatures } from "../../src/exchange/mixins/Signatures.sol";
import { Trading } from "../../src/exchange/mixins/Trading.sol";

interface ExchangeVm {
    function addr(uint256 privateKey) external returns (address);
    function sign(uint256 privateKey, bytes32 digest) external returns (uint8 v, bytes32 r, bytes32 s);
    function prank(address sender) external;
    function startPrank(address sender) external;
    function stopPrank() external;
    function warp(uint256 timestamp) external;
    function expectRevert() external;
    function expectRevert(bytes4 revertData) external;
    function expectRevert(bytes calldata revertData) external;
}

abstract contract ExchangeTest {
    ExchangeVm internal constant vm = ExchangeVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bool public IS_TEST = true;

    function bound(uint256 value, uint256 minimum, uint256 maximum) internal pure returns (uint256) {
        return minimum + (value % (maximum - minimum + 1));
    }

    function assertEq(uint256 left, uint256 right) internal pure {
        require(left == right, "assertEq(uint256)");
    }

    function assertEq(bytes32 left, bytes32 right) internal pure {
        require(left == right, "assertEq(bytes32)");
    }

    function assertEq(bytes4 left, bytes4 right) internal pure {
        require(left == right, "assertEq(bytes4)");
    }

    function assertTrue(bool condition) internal pure {
        require(condition, "assertTrue");
    }

    function assertTrue(bool condition, string memory reason) internal pure {
        require(condition, reason);
    }

    function assertFalse(bool condition) internal pure {
        require(!condition, "assertFalse");
    }

    function assertGe(uint256 left, uint256 right) internal pure {
        require(left >= right, "assertGe");
    }
}

contract ExchangeMockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) { }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}

contract ERC1271OrderWallet is IERC1271 {
    using ECDSA for bytes32;

    address public immutable owner;

    constructor(address owner_) {
        owner = owner_;
    }

    function approveToken(IERC20 token, address spender) external {
        require(msg.sender == owner);
        token.approve(spender, type(uint256).max);
    }

    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4) {
        (address recovered, ECDSA.RecoverError error,) = ECDSA.tryRecover(hash, signature);
        return error == ECDSA.RecoverError.NoError && recovered == owner
            ? IERC1271.isValidSignature.selector
            : bytes4(0xffffffff);
    }
}

contract ReentrantExchangeToken is ERC20 {
    ConditionalExchange public target;
    bool public armed;
    bool public callbackAttempted;
    bool public callbackSucceeded;
    bytes4 public callbackError;

    constructor() ERC20("Reentrant Outcome", "ROUT") { }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function arm(ConditionalExchange target_) external {
        target = target_;
        armed = true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (armed && msg.sender == address(target)) {
            armed = false;
            callbackAttempted = true;
            Order[] memory orders = new Order[](0);
            uint256[] memory amounts = new uint256[](0);
            (bool success, bytes memory data) =
                address(target).call(abi.encodeCall(ConditionalExchange.fillOrders, (orders, amounts)));
            callbackSucceeded = success;
            if (data.length >= 4) {
                callbackError = bytes4(data);
            }
        }
        return super.transferFrom(from, to, amount);
    }
}

abstract contract ConditionalExchangeTestBase is ExchangeTest {
    uint256 internal constant BUYER_PK = 0xA11CE;
    uint256 internal constant SELLER_ONE_PK = 0xB0B;
    uint256 internal constant SELLER_TWO_PK = 0xCA414;
    uint256 internal constant RELAYER_PK = 0xD00D;

    address internal buyer;
    address internal sellerOne;
    address internal sellerTwo;
    address internal relayer;

    ConditionalExchange internal exchange;
    ExchangeMockERC20 internal outcome;
    ExchangeMockERC20 internal quote;
    uint256 internal tokenId;

    function setUp() public virtual {
        buyer = vm.addr(BUYER_PK);
        sellerOne = vm.addr(SELLER_ONE_PK);
        sellerTwo = vm.addr(SELLER_TWO_PK);
        relayer = vm.addr(RELAYER_PK);

        outcome = new ExchangeMockERC20("YES Outcome", "YES");
        quote = new ExchangeMockERC20("YES Quote", "YES-Q");
        exchange = new ConditionalExchange(address(this));
        exchange.registerPair(address(outcome), address(quote));
        tokenId = uint256(uint160(address(outcome)));

        outcome.mint(sellerOne, type(uint128).max);
        outcome.mint(sellerTwo, type(uint128).max);
        quote.mint(buyer, type(uint128).max);

        _approveAll(buyer);
        _approveAll(sellerOne);
        _approveAll(sellerTwo);
    }

    function _approveAll(address account) internal {
        vm.startPrank(account);
        outcome.approve(address(exchange), type(uint256).max);
        quote.approve(address(exchange), type(uint256).max);
        vm.stopPrank();
    }

    function _unsignedOrder(address maker, Side side, uint256 makerAmount, uint256 takerAmount, uint256 salt)
        internal
        view
        returns (Order memory order)
    {
        order = Order({
            salt: salt,
            maker: maker,
            signer: maker,
            taker: address(0),
            tokenId: tokenId,
            makerAmount: makerAmount,
            takerAmount: takerAmount,
            expiration: 0,
            nonce: exchange.nonces(maker),
            feeRateBps: 0,
            side: side,
            signatureType: SignatureType.EOA,
            signature: ""
        });
    }

    function _signedOrder(uint256 privateKey, Side side, uint256 makerAmount, uint256 takerAmount, uint256 salt)
        internal
        returns (Order memory order)
    {
        order = _unsignedOrder(vm.addr(privateKey), side, makerAmount, takerAmount, salt);
        order.signature = _sign(privateKey, exchange.hashOrder(order));
    }

    function _sign(uint256 privateKey, bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _singleton(Order memory order) internal pure returns (Order[] memory orders) {
        orders = new Order[](1);
        orders[0] = order;
    }

    function _singleton(uint256 amount) internal pure returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = amount;
    }

    function _status(Order memory order) internal view returns (OrderStatus memory) {
        return exchange.getOrderStatus(exchange.hashOrder(order));
    }
}

contract ConditionalExchangeHashingAndSignatureTest is ConditionalExchangeTestBase {
    function test_OrderTypehashIsByteExactPolymarketV1() public view {
        bytes32 expected = keccak256(
            bytes(
                "Order(uint256 salt,address maker,address signer,address taker,uint256 tokenId,uint256 makerAmount,uint256 takerAmount,uint256 expiration,uint256 nonce,uint256 feeRateBps,uint8 side,uint8 signatureType)"
            )
        );
        assertEq(ORDER_TYPEHASH, expected);
        assertEq(exchange.orderTypehash(), expected);
    }

    function test_HashMatchesManualEip712EncodingAndExcludesSignature() public view {
        Order memory order = _unsignedOrder(buyer, Side.BUY, 60 ether, 100 ether, 71);
        bytes32 structHash = keccak256(
            abi.encode(
                ORDER_TYPEHASH,
                order.salt,
                order.maker,
                order.signer,
                order.taker,
                order.tokenId,
                order.makerAmount,
                order.takerAmount,
                order.expiration,
                order.nonce,
                order.feeRateBps,
                order.side,
                order.signatureType
            )
        );
        bytes32 domain = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("Futarchy Exchange"),
                keccak256("1"),
                block.chainid,
                address(exchange)
            )
        );
        bytes32 expected = keccak256(abi.encodePacked("\x19\x01", domain, structHash));
        assertEq(exchange.domainSeparator(), domain);
        assertEq(exchange.hashOrder(order), expected);

        bytes32 beforeSignature = exchange.hashOrder(order);
        order.signature = hex"deadbeef";
        assertEq(exchange.hashOrder(order), beforeSignature);
    }

    function test_RevertForgedMakerEvenWhenForgedMakerApproved() public {
        Order memory forged = _unsignedOrder(buyer, Side.BUY, 50 ether, 100 ether, 1);
        forged.signer = sellerOne;
        forged.signature = _sign(SELLER_ONE_PK, exchange.hashOrder(forged));

        vm.expectRevert(Signatures.InvalidSignature.selector);
        vm.prank(sellerOne);
        exchange.fillOrder(forged, 50 ether);
    }

    function test_Eip1271MakerCanFill() public {
        uint256 walletOwnerPk = 0x1271;
        address walletOwner = vm.addr(walletOwnerPk);
        ERC1271OrderWallet wallet = new ERC1271OrderWallet(walletOwner);
        outcome.mint(address(wallet), 10 ether);
        vm.prank(walletOwner);
        wallet.approveToken(outcome, address(exchange));
        quote.mint(buyer, 10 ether);

        Order memory order = _unsignedOrder(address(wallet), Side.SELL, 10 ether, 4 ether, 1271);
        order.signatureType = SignatureType.EIP1271;
        order.signature = _sign(walletOwnerPk, exchange.hashOrder(order));

        vm.prank(buyer);
        exchange.fillOrder(order, 10 ether);

        assertEq(outcome.balanceOf(buyer), 10 ether);
        assertEq(quote.balanceOf(address(wallet)), 4 ether);
    }

    function test_RevertUnsupportedSignatureType() public {
        Order memory order = _unsignedOrder(buyer, Side.BUY, 1 ether, 1 ether, 8);
        order.signatureType = SignatureType.UNUSED_1;

        vm.expectRevert(abi.encodeWithSelector(Signatures.UnsupportedSignatureType.selector, SignatureType.UNUSED_1));
        vm.prank(sellerOne);
        exchange.fillOrder(order, 1 ether);
    }
}

contract ConditionalExchangeFillTest is ConditionalExchangeTestBase {
    function test_FillBuyOrderDerivesQuoteAndOutcomeAssets() public {
        Order memory buy = _signedOrder(BUYER_PK, Side.BUY, 5 ether, 10 ether, 91);
        uint256 buyerQuoteBefore = quote.balanceOf(buyer);

        vm.prank(sellerOne);
        exchange.fillOrder(buy, 5 ether);

        assertEq(outcome.balanceOf(buyer), 10 ether);
        assertEq(quote.balanceOf(sellerOne), 5 ether);
        assertEq(buyerQuoteBefore - quote.balanceOf(buyer), 5 ether);
    }

    function test_FillOrderSwapsDirectlyAndTracksPartialFill() public {
        Order memory sell = _signedOrder(SELLER_ONE_PK, Side.SELL, 100 ether, 55 ether, 1);

        vm.prank(buyer);
        exchange.fillOrder(sell, 40 ether);

        assertEq(outcome.balanceOf(buyer), 40 ether);
        assertEq(quote.balanceOf(sellerOne), 22 ether);
        OrderStatus memory status = _status(sell);
        assertFalse(status.isFilledOrCancelled);
        assertEq(status.remaining, 60 ether);
    }

    function test_FillOrdersIsPermissionlessBatchSettlement() public {
        Order memory first = _signedOrder(SELLER_ONE_PK, Side.SELL, 10 ether, 5 ether, 1);
        Order memory second = _signedOrder(SELLER_TWO_PK, Side.SELL, 20 ether, 8 ether, 2);
        Order[] memory orders = new Order[](2);
        orders[0] = first;
        orders[1] = second;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10 ether;
        amounts[1] = 20 ether;

        vm.prank(buyer);
        exchange.fillOrders(orders, amounts);

        assertEq(outcome.balanceOf(buyer), 30 ether);
        assertTrue(_status(first).isFilledOrCancelled);
        assertTrue(_status(second).isFilledOrCancelled);
    }

    function test_SignedFeeRateIsMaximumAndChargedFeeIsZero() public {
        Order memory sell = _signedOrder(SELLER_ONE_PK, Side.SELL, 10 ether, 5 ether, 1);
        sell.feeRateBps = type(uint256).max;
        sell.signature = _sign(SELLER_ONE_PK, exchange.hashOrder(sell));

        vm.prank(buyer);
        exchange.fillOrder(sell, 10 ether);

        assertEq(exchange.CHARGED_FEE_RATE_BPS(), 0);
        assertEq(quote.balanceOf(sellerOne), 5 ether);
    }

    function test_RestrictedTakerRejectsOtherCaller() public {
        Order memory sell = _signedOrder(SELLER_ONE_PK, Side.SELL, 10 ether, 5 ether, 1);
        sell.taker = relayer;
        sell.signature = _sign(SELLER_ONE_PK, exchange.hashOrder(sell));

        vm.expectRevert(Trading.NotTaker.selector);
        vm.prank(buyer);
        exchange.fillOrder(sell, 10 ether);
    }

    function test_RevertFillAboveRemaining() public {
        Order memory sell = _signedOrder(SELLER_ONE_PK, Side.SELL, 10 ether, 5 ether, 1);

        vm.expectRevert(Trading.MakingAmountExceedsRemaining.selector);
        vm.prank(buyer);
        exchange.fillOrder(sell, 10 ether + 1);
    }

    function test_RevertBatchLengthMismatch() public {
        Order memory sell = _signedOrder(SELLER_ONE_PK, Side.SELL, 10 ether, 5 ether, 1);
        uint256[] memory noAmounts = new uint256[](0);

        vm.expectRevert(Trading.ArrayLengthMismatch.selector);
        vm.prank(buyer);
        exchange.fillOrders(_singleton(sell), noAmounts);
    }

    function test_CumulativeCeilingRoundingFavorsMakerWithoutOverchargingFullOrder() public {
        Order memory sell = _signedOrder(SELLER_ONE_PK, Side.SELL, 7, 3, 1);

        vm.prank(buyer);
        exchange.fillOrder(sell, 2);
        assertEq(quote.balanceOf(sellerOne), 1);
        assertGe(quote.balanceOf(sellerOne) * 7, 2 * 3);

        vm.prank(buyer);
        exchange.fillOrder(sell, 2);
        assertEq(quote.balanceOf(sellerOne), 2);
        assertGe(quote.balanceOf(sellerOne) * 7, 4 * 3);

        vm.prank(buyer);
        exchange.fillOrder(sell, 3);
        assertEq(quote.balanceOf(sellerOne), 3);
        assertTrue(_status(sell).isFilledOrCancelled);
    }

    function testFuzz_PartialFillRatioUsesCumulativeMakerFavoringCeiling(
        uint128 makerAmountInput,
        uint128 takerAmountInput,
        uint128 firstFillInput
    ) public {
        uint256 makerAmount = bound(uint256(makerAmountInput), 1, 1e30);
        uint256 takerAmount = bound(uint256(takerAmountInput), 1, 1e30);
        uint256 firstFill = bound(uint256(firstFillInput), 1, makerAmount);
        uint256 salt = uint256(keccak256(abi.encode(makerAmount, takerAmount, firstFill)));
        Order memory sell = _signedOrder(SELLER_ONE_PK, Side.SELL, makerAmount, takerAmount, salt);

        vm.prank(buyer);
        exchange.fillOrder(sell, firstFill);

        uint256 expectedFirst = Math.mulDiv(firstFill, takerAmount, makerAmount, Math.Rounding.Ceil);
        assertEq(quote.balanceOf(sellerOne), expectedFirst);
        assertGe(expectedFirst, Math.mulDiv(firstFill, takerAmount, makerAmount));

        if (firstFill < makerAmount) {
            vm.prank(buyer);
            exchange.fillOrder(sell, makerAmount - firstFill);
        }
        assertEq(quote.balanceOf(sellerOne), takerAmount);
        assertTrue(_status(sell).isFilledOrCancelled);
    }
}

contract ConditionalExchangeMatchTest is ConditionalExchangeTestBase {
    function test_MatchOrdersOneTakerManyMakersAndBothSidesAccounting() public {
        Order memory buy = _signedOrder(BUYER_PK, Side.BUY, 60 ether, 100 ether, 1);
        Order memory sellOne = _signedOrder(SELLER_ONE_PK, Side.SELL, 40 ether, 20 ether, 2);
        Order memory sellTwo = _signedOrder(SELLER_TWO_PK, Side.SELL, 60 ether, 30 ether, 3);
        Order[] memory makers = new Order[](2);
        makers[0] = sellOne;
        makers[1] = sellTwo;
        uint256[] memory fills = new uint256[](2);
        fills[0] = 40 ether;
        fills[1] = 60 ether;

        vm.prank(relayer);
        exchange.matchOrders(buy, makers, 60 ether, fills);

        assertEq(outcome.balanceOf(buyer), 100 ether);
        assertEq(quote.balanceOf(sellerOne), 20 ether);
        assertEq(quote.balanceOf(sellerTwo), 30 ether);
        assertTrue(_status(buy).isFilledOrCancelled, "taker order must be decremented");
        assertTrue(_status(sellOne).isFilledOrCancelled, "first maker order must be decremented");
        assertTrue(_status(sellTwo).isFilledOrCancelled, "second maker order must be decremented");
    }

    function test_PriceImprovementAccruesToTaker() public {
        Order memory buy = _signedOrder(BUYER_PK, Side.BUY, 60 ether, 100 ether, 1);
        Order memory sell = _signedOrder(SELLER_ONE_PK, Side.SELL, 100 ether, 40 ether, 2);
        uint256 buyerQuoteBefore = quote.balanceOf(buyer);

        vm.prank(relayer);
        exchange.matchOrders(buy, _singleton(sell), 60 ether, _singleton(100 ether));

        assertEq(buyerQuoteBefore - quote.balanceOf(buyer), 40 ether);
        assertEq(outcome.balanceOf(buyer), 100 ether);
    }

    function test_MatchOrdersIsSymmetricForActiveSell() public {
        Order memory sell = _signedOrder(SELLER_ONE_PK, Side.SELL, 100 ether, 50 ether, 1);
        Order memory buy = _signedOrder(BUYER_PK, Side.BUY, 60 ether, 100 ether, 2);

        vm.prank(relayer);
        exchange.matchOrders(sell, _singleton(buy), 100 ether, _singleton(60 ether));

        assertEq(outcome.balanceOf(buyer), 100 ether);
        assertEq(quote.balanceOf(sellerOne), 60 ether);
        assertTrue(_status(sell).isFilledOrCancelled);
        assertTrue(_status(buy).isFilledOrCancelled);
    }

    function test_RevertNonCrossingOrders() public {
        Order memory buy = _signedOrder(BUYER_PK, Side.BUY, 40 ether, 100 ether, 1);
        Order memory sell = _signedOrder(SELLER_ONE_PK, Side.SELL, 100 ether, 50 ether, 2);

        vm.expectRevert(Trading.NotCrossing.selector);
        vm.prank(relayer);
        exchange.matchOrders(buy, _singleton(sell), 40 ether, _singleton(100 ether));
    }

    function test_RevertMintAndMergeSameSidePaths() public {
        Order memory buy = _signedOrder(BUYER_PK, Side.BUY, 50 ether, 100 ether, 1);
        Order memory secondBuy = _signedOrder(SELLER_ONE_PK, Side.BUY, 50 ether, 100 ether, 2);

        vm.expectRevert(Trading.NotCrossing.selector);
        vm.prank(relayer);
        exchange.matchOrders(buy, _singleton(secondBuy), 50 ether, _singleton(50 ether));
    }
}

contract ConditionalExchangeInvalidationAndPauseTest is ConditionalExchangeTestBase {
    function test_RevertAfterExpiration() public {
        Order memory sell = _signedOrder(SELLER_ONE_PK, Side.SELL, 10 ether, 5 ether, 1);
        sell.expiration = block.timestamp + 1 hours;
        sell.signature = _sign(SELLER_ONE_PK, exchange.hashOrder(sell));
        vm.warp(sell.expiration + 1);

        vm.expectRevert(Trading.OrderExpired.selector);
        vm.prank(buyer);
        exchange.fillOrder(sell, 10 ether);
    }

    function test_RevertAfterCancel() public {
        Order memory sell = _signedOrder(SELLER_ONE_PK, Side.SELL, 10 ether, 5 ether, 1);
        vm.prank(sellerOne);
        exchange.cancelOrder(sell);

        vm.expectRevert(Trading.OrderFilledOrCancelled.selector);
        vm.prank(buyer);
        exchange.fillOrder(sell, 10 ether);
    }

    function test_OnlyMakerCanCancel() public {
        Order memory sell = _signedOrder(SELLER_ONE_PK, Side.SELL, 10 ether, 5 ether, 1);

        vm.expectRevert(Trading.NotOrderMaker.selector);
        vm.prank(buyer);
        exchange.cancelOrder(sell);
    }

    function test_RevertAfterNonceIncrement() public {
        Order memory sell = _signedOrder(SELLER_ONE_PK, Side.SELL, 10 ether, 5 ether, 1);
        vm.prank(sellerOne);
        exchange.incrementNonce();

        vm.expectRevert(Trading.InvalidNonce.selector);
        vm.prank(buyer);
        exchange.fillOrder(sell, 10 ether);
    }

    function test_PauseBlocksEveryFillPathButNotCancellation() public {
        Order memory sell = _signedOrder(SELLER_ONE_PK, Side.SELL, 10 ether, 5 ether, 1);
        exchange.pauseTrading();

        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(buyer);
        exchange.fillOrder(sell, 10 ether);

        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(buyer);
        exchange.fillOrders(_singleton(sell), _singleton(10 ether));

        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(relayer);
        exchange.matchOrders(sell, _singleton(sell), 10 ether, _singleton(10 ether));

        vm.prank(sellerOne);
        exchange.cancelOrder(sell);
        assertTrue(_status(sell).isFilledOrCancelled);
    }

    function test_OnlyOwnerCanPauseAndRegisterPair() public {
        vm.expectRevert();
        vm.prank(relayer);
        exchange.pauseTrading();

        ExchangeMockERC20 anotherOutcome = new ExchangeMockERC20("Another", "AN");
        vm.expectRevert();
        vm.prank(relayer);
        exchange.registerPair(address(anotherOutcome), address(quote));
    }

    function test_PairRegistrationCannotBeReplaced() public {
        ExchangeMockERC20 replacementQuote = new ExchangeMockERC20("Replacement", "RQ");

        vm.expectRevert(abi.encodeWithSelector(PairRegistry.PairAlreadyRegistered.selector, address(outcome)));
        exchange.registerPair(address(outcome), address(replacementQuote));
    }

    function test_RevertUnregisteredToken() public {
        ExchangeMockERC20 unregistered = new ExchangeMockERC20("Unregistered", "UN");
        Order memory sell = _signedOrder(SELLER_ONE_PK, Side.SELL, 10 ether, 5 ether, 1);
        sell.tokenId = uint256(uint160(address(unregistered)));
        sell.signature = _sign(SELLER_ONE_PK, exchange.hashOrder(sell));

        vm.expectRevert(abi.encodeWithSelector(PairRegistry.PairNotRegistered.selector, sell.tokenId));
        vm.prank(buyer);
        exchange.fillOrder(sell, 10 ether);
    }
}

contract ConditionalExchangeReentrancyTest is ExchangeTest {
    function test_TokenCallbackCannotReenterAnyFillPath() public {
        uint256 sellerPk = 0x5151;
        address seller = vm.addr(sellerPk);
        address buyer = vm.addr(0xB0B0);
        ReentrantExchangeToken outcome = new ReentrantExchangeToken();
        ExchangeMockERC20 quote = new ExchangeMockERC20("Quote", "Q");
        ConditionalExchange exchange = new ConditionalExchange(address(this));
        exchange.registerPair(address(outcome), address(quote));

        outcome.mint(seller, 10 ether);
        quote.mint(buyer, 5 ether);
        vm.prank(seller);
        outcome.approve(address(exchange), type(uint256).max);
        vm.prank(buyer);
        quote.approve(address(exchange), type(uint256).max);

        Order memory sell = Order({
            salt: 1,
            maker: seller,
            signer: seller,
            taker: address(0),
            tokenId: uint256(uint160(address(outcome))),
            makerAmount: 10 ether,
            takerAmount: 5 ether,
            expiration: 0,
            nonce: 0,
            feeRateBps: 0,
            side: Side.SELL,
            signatureType: SignatureType.EOA,
            signature: ""
        });
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPk, exchange.hashOrder(sell));
        sell.signature = abi.encodePacked(r, s, v);
        outcome.arm(exchange);

        vm.prank(buyer);
        exchange.fillOrder(sell, 10 ether);

        assertTrue(outcome.callbackAttempted());
        assertFalse(outcome.callbackSucceeded());
        assertTrue(outcome.callbackError() == ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        assertEq(outcome.balanceOf(buyer), 10 ether);
    }
}
