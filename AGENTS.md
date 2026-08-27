# AGENTS.md

You are helping with **v4hooks**, a directory of Uniswap v4 hook example contracts (https://v4hooks.com).

## What this repo is

- Source of truth: `hooks/*.yml` — each file is a licensed Solidity excerpt + GitHub permalink
- First-party examples: `contracts/*.sol` + `test/*.t.sol` (Foundry). May rewrite legacy hooks for current v4.
- `kind: pattern` = implement this. `kind: product` = study a live protocol’s callbacks
- `properties`: `dynamic-fee` | `upgradeable` | `custom-swap-data` | `vanilla-swap`
- Site: Astro static pages in `src/pages`
- Ads API: `src/worker.ts` + D1 `v4hooks-ads`
- Do **not** clone Uniswap/hooklist. Link to it for addresses.
- Do **not** invent Solidity or contract addresses (YAML excerpts must match a real file).

## Read first

- `README.md`, `CONTRIBUTING.md`, `schema/hook.schema.json`
- Generated at build: `public/llms.txt`, `public/llm-full.txt`, `public/hooks.json`

## Keep user-facing docs current

If a change affects how humans or agents use the site, update docs **in the same commit**: `README.md`, `CONTRIBUTING.md`, this file, `SKILLS.md`, `public/skills.md`, `SECURITY.md`. Add a page agents should see → edit `scripts/generate-agent-files.mjs`, then `npm run build` so `public/llms.txt`, `public/llm-full.txt`, and `public/hooks.json` match. CSS-only restyles do not need a doc pass.

## Tasks

- Add a hook listing: copy `hooks/_template.yml` to `hooks/{slug}.yml`, then `npm run validate`. Files starting with `_` are not listings.
- Add a first-party hook: write `contracts/{Name}.sol` + `test/{Name}.t.sol`, `forge test`, then add the YAML listing.
- Change copy/SEO: edit the page under `src/pages` and keep JSON-LD accurate.
- Ads: Worker routes `/api/ads`, `/api/ads/intent`, `/api/ads/webhook`. Min bid 5 USDC.

## Commands

```
npm run validate
npm run build
forge build
forge test
```

## Do not

- Invent contract addresses or Solidity.
- Claim listings are audited or official Uniswap routing.
- Commit `.dev.vars` or secrets.
