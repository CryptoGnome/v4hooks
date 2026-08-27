# First-party hooks

Solidity we publish in this repo and list on v4hooks.com.

## Layout

- `contracts/` — hook sources (permalink targets for `hooks/*.yml`)
- `test/` — Foundry tests (required for every contract)
- `lib/` — git submodules (`OpenZeppelin/uniswap-hooks`, `forge-std`, nested v4-core/periphery)

## Commands

```bash
forge build
forge test
npm run forge:test   # same
npm run validate     # YAML catalog
```

## Rules

- Inherit OpenZeppelin `BaseHook`. Full 14 permission fields. No `tx.origin`, no `updateDynamicSwapFee`.
- Adapt legacy hooks with attribution; fix the API on purpose; say what changed in the listing.
- Listing is not an audit. `status: experimental` until you have a stronger claim (and evidence).

See `CONTRIBUTING.md` → First-party hooks.

## Catalogued examples

| Contract | Listing | Hackathon / inspiration |
|----------|---------|-------------------------|
| `SuckerPunch.sol` | `sucker-punch` | EthLondon PopFendi |
| `AntiSnipe.sol` | `anti-snipe` | Spark launchpad |
| `SurgeFee.sol` | `surge-fee` | Spark launchpad |
| `AutoBurn.sol` | `auto-burn` | Spark launchpad |
| `LpRewards.sol` | `lp-rewards` | Spark launchpad |
| `NthBuyPot.sol` | `nth-buy-pot` | Spark launchpad |
| `StopLoss.sol` | `stop-loss` | saucepoint v4-stoploss |
| `TakeProfit.sol` | `take-profits` | LearnWeb3 take-profits |
| `TrailingStop.sol` | `trailing-stop` | Hookathon C1 Trailing Hook |
| `TradingDays.sol` | `trading-days` | horsefacts trading-days |
| `LiquidityBootstrapping.sol` | `liquidity-bootstrapping` | kadenzipfel uni-lbp |
| `SellGuard.sol` | `sell-guard` | FairTrade / SafeSwap |
| `VolumeTier.sol` | `volume-tier` | EthLondon Royalty Swap |
| `MevDonate.sol` | `mev-donate` | FairArbooors / Detox |
| `LiquidityLock.sol` | `liquidity-lock` | Hookathon C1 LiquidityLock |
| `MedianOracle.sol` | `median-oracle` | saucepoint median-oracles |
| `ReferralFee.sol` | `referral-fee` | mergd/ref-fee-hook |
| `Buyback.sol` | `buyback` | atj3097/buyback-hook |
