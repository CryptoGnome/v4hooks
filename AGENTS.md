# AGENTS.md

You are helping with **v4hooks**, a directory of Uniswap v4 hook example contracts (https://v4hooks.com).

## What this repo is

- Source of truth: `hooks/*.yml` — each file is a licensed Solidity excerpt + GitHub permalink
- `kind: pattern` = implement this. `kind: product` = study a live protocol’s callbacks
- `properties`: `dynamic-fee` | `upgradeable` | `custom-swap-data` | `vanilla-swap`
- Site: Astro static pages in `src/pages`
- Ads API: `src/worker.ts` + D1 `v4hooks-ads`
- Do **not** clone Uniswap/hooklist. Link to it for addresses.
- Do **not** invent Solidity or contract addresses.

## Read first

- `README.md`, `CONTRIBUTING.md`, `schema/hook.schema.json`
- Generated at build: `public/llms.txt`, `public/llm-full.txt`, `public/hooks.json`

## Tasks

- Add a hook: copy `hooks/_template.yml` to `hooks/{slug}.yml`, then `npm run validate`. Files starting with `_` are not listings.
- Change copy/SEO: edit the page under `src/pages` and keep JSON-LD accurate.
- Ads: Worker routes `/api/ads`, `/api/ads/intent`, `/api/ads/webhook`. Min bid 5 USDC.

## Commands

```
npm run validate
npm run build
```

## Do not

- Invent contract addresses or Solidity.
- Claim listings are audited or official Uniswap routing.
- Commit `.dev.vars` or secrets.
