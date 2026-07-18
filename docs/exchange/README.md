# Conditional Exchange

`ConditionalExchange` settles signed limit orders for futarchy.fi's wrapped ERC-20 conditional markets. It is a
non-custodial settlement contract: makers retain their assets until a fill, every asset leg moves directly between the
economic counterparties with `SafeERC20.transferFrom`, and any address may submit a valid fill.

This version implements the frozen futarchy.fi scope: **COMPLEMENTARY swaps only**. A registered wrapped outcome token
is exchanged against its corresponding wrapped quote/collateral token, such as `YES_GNO` against `YES_sDAI`.

## Architecture

- `ConditionalExchange.sol` exposes the fill entrypoints and owner-controlled emergency pause.
- `OrderStructs.sol` preserves the Polymarket V1 `Order` shape and verbatim `ORDER_TYPEHASH`.
- `Hashing.sol` supplies the EIP-712 domain `Futarchy Exchange`, version `1`, and order hashing.
- `Signatures.sol` validates ECDSA and EIP-1271 signatures. Both paths require `maker == signer`; ECDSA validation also
  works for EIP-7702 delegated EOAs.
- `PairRegistry.sol` maps `tokenId = uint256(uint160(outcomeToken))` to a quote token. Registrations are owner-only,
  append-only, and cannot be replaced.
- `Trading.sol` owns order status, nonce invalidation, cancellation, ratio accounting, and direct ERC-20 settlement.

An order's `makerAmount` is always the amount offered by its maker. A BUY maker offers the registered quote token and
receives the outcome token. A SELL maker offers the outcome token and receives the quote token. `fillAmount`,
`takerFillAmount`, and every `makerFillAmount` are denominated in the relevant order's maker asset.

Partial fills use cumulative ceiling rounding:

```text
cumulative taker amount = ceil(cumulative maker fill * takerAmount / makerAmount)
```

Each incremental payment is the difference between the new and old cumulative values. The resting maker therefore
never falls below its signed ratio, while repeated partial fills cannot collect more than the signed total.

### Fill paths

`fillOrder` and `fillOrders` settle signed orders against `msg.sender`. A nonzero signed `taker` restricts who may call
the fill; zero makes the order public.

`matchOrders` matches one active order against one or more opposite-side orders for the same registered outcome token.
The caller is only a permissionless transaction submitter. Each maker receives its signed ratio, both active and
resting order statuses are decremented, and any price improvement belongs to the active-order maker. Improvement can
appear as more received assets or less actual spend than the active order's maker-amount fill allowance.

All fill entrypoints are paused together and protected by a single reentrancy guard. Checks and order-status effects
complete before ERC-20 interactions. A failed leg reverts the entire transaction.

## Order lifecycle and fees

Orders are EIP-712 messages and are never placed on chain. They become unfillable when fully filled, cancelled by the
maker, invalidated by the maker's global nonce increment, or expired. Cancellation and nonce increment remain available
while trading is paused.

`feeRateBps` is the maker's signed maximum acceptable rate. This release hardcodes the charged rate and fee amount to
zero, so every order's signed maximum is respected. Adding nonzero fees requires a new reviewed deployment; it must use
the frozen symmetric `baseRate * min(p, 1-p) * size` formula and must never exceed the signed maximum.

## Trust model

There is no operator and no privileged fill path. A relayer cannot modify an order, forge a maker, redirect proceeds,
or bypass price, status, nonce, expiry, pair, pause, or signature checks.

The owner can:

- register a new outcome/quote pair;
- pause and unpause fills; and
- transfer or renounce ownership through OpenZeppelin `Ownable`.

The owner cannot replace an existing pair, fill or cancel user orders without satisfying the normal rules, move user
balances, or withdraw assets. For production, ownership should be transferred to the team-approved multisig or
governance executor. Pair registration remains security-sensitive: only audited, exact-transfer ERC-20 wrappers should
be admitted. Fee-on-transfer, rebasing, callback-bearing, or otherwise nonstandard tokens are outside the intended
asset model even though fill reentrancy is guarded.

The exchange is intentionally non-upgradeable. The deployment address and chain ID are part of the EIP-712 domain, so
orders cannot be replayed against another deployment or chain.

## Relay expectations

Relays are optional, stateless discovery services. Anyone can run one. A relay should validate the signature, current
nonce, expiration, registered pair, remaining amount, maker balance, and maker allowance before advertising an order,
but relay validation is only an optimization: the contract rechecks authoritative conditions during settlement.

Suggested interfaces follow the shared protocol:

- `POST /orders` accepts a signed order.
- `GET /book?tokenId=` returns an order book.
- `GET /orders?maker=` returns a maker's orders.
- WebSocket feeds publish book deltas and mirror `OrderFilled`, `OrdersMatched`, `OrderCancelled`, and nonce events.

Relays never receive token custody and have no on-chain authorization. Users cancel on chain or distribute newly signed
orders with a later nonce/expiration policy.

## Deployment considerations

1. Resolve the wrapped tokens from the intended `IFutarchyProposal`. `wrappedOutcome(index)` is the source of outcome
   token addresses; pair each traded outcome with the correct conditional quote/collateral leg.
2. Independently verify token implementations, proposal identity, decimals, and outcome semantics. The registry does
   not infer or prove economic relationships.
3. Deploy with the temporary deployment administrator, verify bytecode and constructor arguments, register reviewed
   pairs, and transfer ownership to the approved administrator.
4. Makers and direct takers must approve the exchange for the assets they offer. Matched orders require approvals from
   the active maker and every resting maker; the transaction submitter needs no asset approval.
5. Confirm EIP-712 output with production signing clients, monitor registry/pause/ownership events, and run an external
   audit before a real-money Gnosis deployment.

The Gnosis fork test covers the live KIP-88 `YES_PNK` (`0x45DA...76dB`) and `YES_sDAI` (`0x43DA...57a3`) wrappers.

## Deferred MINT and MERGE

MINT (two BUY orders) and MERGE (two SELL orders) do not exist in this contract. futarchy.fi proposals use two
collateral legs, so the single-collateral Polymarket mint/merge mechanism cannot be copied safely. Supporting those
paths requires a separately specified dual-collateral accounting model, new solvency invariants, additional external
protocol interactions, dedicated tests, and a new audit. Same-side orders currently revert as non-crossing.
