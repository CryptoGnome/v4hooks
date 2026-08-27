# Contributing to v4hooks

v4hooks is a directory of **example Uniswap v4 hook contracts** for agents and builders. One YAML file per hook. The body is a licensed Solidity excerpt plus a GitHub permalink to the full file. Not a clone of Uniswap/hooklist.

## First-party hooks

Interesting legacy hooks that do not compile on current v4 can be **rewritten** under [`contracts/`](contracts/) and listed with `source` pointing at this repo.

1. Add `contracts/{Name}.sol` (MIT + attribution if adapted).
2. Add `test/{Name}.t.sol`. Run `forge build` and `forge test`.
3. Add `hooks/{slug}.yml` with a matching excerpt and permalink to `contracts/…`.
4. Run `npm run validate` (and regenerate agent files on build).

CI runs forge tests on every PR. Cursor rules under `.cursor/rules/` enforce the audit checklist when those files are open.

Do not invent Solidity only inside the YAML — the listing must match a real file.

## Rules

- Filename `hooks/{slug}.yml` must match `slug`.
- `kind` is `pattern` (implement this) or `product` (production hook, study the callbacks).
- `source.url` must be an `https://github.com/` permalink to the `.sol` file. `source.repo` is the repo root.
- `solidity` is an excerpt: `getHookPermissions` (or `getHooksCalls`) plus the callbacks that matter. Not the whole contract.
- `description` ≥ 280 characters, unique, explains the callbacks.
- `flags` must match the excerpt. `properties` tags behavior: `dynamic-fee`, `upgradeable`, `custom-swap-data`, `vanilla-swap`.
- `license` is the SPDX from that file.
- HTTPS only for `website`, `docs`, `audit_url`.
- Chains must be in the allowlist in `scripts/validate.mjs`.
- Addresses lowercase `0x` + 40 hex. Do not invent addresses.
- Listing is not an audit. Do not claim Uniswap endorsement or that the snippet is safe to deploy.

## Steps

1. Fork the repo.
2. Copy [`hooks/_template.yml`](hooks/_template.yml) to `hooks/{slug}.yml`.
3. Fill it. Delete comments. Run `npm run validate`.
4. Open a PR. A maintainer must merge. CI checks catalog schema **and** `forge test`.

## What we will reject

- Listings with no public Solidity file we can permalink.
- Invented or paraphrased code (must match the source file).
- Raw hooklist dumps (one file per address, no callbacks).
- Thin pages or copied Uniswap docs.
- Affiliate tracking query strings.

## Advertise

There is no paid placement right now. Do not PR ads into `hooks/`.
