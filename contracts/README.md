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
