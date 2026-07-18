// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ConditionalExchange } from "../../src/exchange/ConditionalExchange.sol";
import { Order, Side, SignatureType } from "../../src/exchange/libraries/OrderStructs.sol";

contract ConditionalExchangeGnosisForkTest is Test {
    address internal constant YES_PNK = 0x45DA0089E53f41998449EDC7A62B74afA7db76dB;
    address internal constant YES_SDAI = 0x43DAa59fa6f6C32bedfbBDFb00DaBA8b856257a3;

    function testFork_RealKip88ConditionalTokensSettleDirectly() public {
        vm.createSelectFork("gnosis");

        uint256 sellerPk = 0x5151;
        uint256 buyerPk = 0xB0B0;
        address seller = vm.addr(sellerPk);
        address buyer = vm.addr(buyerPk);
        uint256 outcomeAmount = 1 ether;
        uint256 quoteAmount = 0.5 ether;

        ConditionalExchange exchange = new ConditionalExchange(address(this));
        exchange.registerPair(YES_PNK, YES_SDAI);

        deal(YES_PNK, seller, outcomeAmount);
        deal(YES_SDAI, buyer, quoteAmount);
        vm.prank(seller);
        IERC20(YES_PNK).approve(address(exchange), type(uint256).max);
        vm.prank(buyer);
        IERC20(YES_SDAI).approve(address(exchange), type(uint256).max);

        Order memory sell = Order({
            salt: 88,
            maker: seller,
            signer: seller,
            taker: address(0),
            tokenId: uint256(uint160(YES_PNK)),
            makerAmount: outcomeAmount,
            takerAmount: quoteAmount,
            expiration: 0,
            nonce: 0,
            feeRateBps: 0,
            side: Side.SELL,
            signatureType: SignatureType.EOA,
            signature: ""
        });
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPk, exchange.hashOrder(sell));
        sell.signature = abi.encodePacked(r, s, v);

        vm.prank(buyer);
        exchange.fillOrder(sell, outcomeAmount);

        assertEq(IERC20(YES_PNK).balanceOf(buyer), outcomeAmount);
        assertEq(IERC20(YES_SDAI).balanceOf(seller), quoteAmount);
        assertEq(IERC20(YES_PNK).balanceOf(address(exchange)), 0);
        assertEq(IERC20(YES_SDAI).balanceOf(address(exchange)), 0);
    }
}
