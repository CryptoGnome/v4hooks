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

| Contract | Listing | Spark-inspired behavior |
|----------|---------|------------------------|
| `SuckerPunch.sol` | `sucker-punch` | Hold-time / MEV sell fees |
| `AntiSnipe.sol` | `anti-snipe` | Guard window, max buy, snipe tax |
| `SurgeFee.sol` | `surge-fee` | Size-vs-liquidity surge fee |
| `AutoBurn.sol` | `auto-burn` | Burn buy output (return delta) |
| `LpRewards.sol` | `lp-rewards` | Donate buy cut to LPs (`flush`) |
| `NthBuyPot.sol` | `nth-buy-pot` | Nth-buy jackpot + claim |
