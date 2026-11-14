# Multi-option futarchy

Futarchy markets with N mutually exclusive options instead of Yes / No, for example "who is announced as the next
CEO": the price of a stock under each candidate, plus the probability of each candidate.

These contracts are adapted from Seer's `FutarchyFactory`, `FutarchyProposal`, `FutarchyRouter` and
`FutarchyRealityProxy`, which are fixed to two outcomes. They use the same ConditionalTokens, Wrapped1155Factory and
Reality.eth v3 contracts as the two-outcome stack. They have not been audited.

## How a market is built

A market has two collateral tokens (a company token such as NVDA, and a currency such as USDG) and N options.

- **One Reality.eth question** (single select) lists the options. The answer is the index of the winning option.
- **One N-slot condition** in ConditionalTokens, whose oracle is `FutarchyMultiRealityProxy`.
- **2N outcome tokens**, wrapped as ERC20s named `SYMBOL_COLLATERAL` (`BUCK_NVDA`, `BUCK_USDG`, …). Each has the
  decimals of its collateral.
- **Splitting** 1 NVDA through `FutarchyMultiRouter.splitPosition` gives 1 of every option's NVDA token; merging is
  the reverse. Same for the currency.

The pools are ordinary Uniswap V3 pools and are not created by these contracts:

- `k_NVDA / k_USDG` prices the company token if option k wins.
- `k_USDG / USDG` prices the probability of option k.

Since 1 NVDA is one of every `k_NVDA`, an arbitrageur keeps `spot = Σ p_k · price_k`.

## The catch-all option, and dividing it later

The **last option is the catch-all** ("Other"). An invalid answer, or an answer outside the list, pays the last
option.

A second market can be created with `parentMarket` and `parentOutcome` pointing at the catch-all of the first. Its
tokens are split from, and redeem into, the first market's catch-all tokens, with no new collateral. That turns
"Other" into named candidates plus a new "Other", and it can be repeated on the new catch-all.

If a candidate of the second list wins, the first question resolves to "Other" and the second to that candidate; the
holder redeems through both levels. If a candidate of the first list wins, every token of the second list is worth
nothing, whatever the second question says.

## Contracts

| File | Role |
|---|---|
| `src/FutarchyMultiFactory.sol` | asks the question, prepares the condition, deploys the 2N tokens and the proposal |
| `src/FutarchyMultiProposal.sol` | one market: options, tokens, parent link |
| `src/FutarchyMultiRouter.sol` | split, merge, redeem (collateral or parent tokens) |
| `src/FutarchyMultiRealityProxy.sol` | reports the final Reality.eth answer to ConditionalTokens |

## Tests

```
cd multi-option
forge test
```

The tests deploy ConditionalTokens, Wrapped1155Factory and Reality.eth v3 from the creation bytecode in `bytecode/`
(the bytecode verified on Ethereum mainnet and deployed on Robinhood Chain), so they run against the real base
contracts without a fork. They cover split and merge for both collaterals, dividing the catch-all once and twice,
redeeming through two and three levels, a named candidate winning, invalid and out-of-range answers, and the
factory's and router's input checks.
