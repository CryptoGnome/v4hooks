# AGENTS.md

You are helping with **v4hooks**, a curated Uniswap v4 hooks directory (https://v4hooks.com).

## What this repo is

- Source of truth: `hooks/*.yml`
- Site: Astro static pages in `src/pages`
- Ads API: `src/worker.ts` + D1 `v4hooks-ads`
- Do **not** clone Uniswap/hooklist. Link to it for addresses.

## Read first

- `README.md`, `CONTRIBUTING.md`, `schema/hook.schema.json`
- Generated at build: `public/llms.txt`, `public/llm-full.txt`, `public/hooks.json`

## Tasks

- Add a hook: new YAML, then `npm run validate`.
- Change copy/SEO: edit the page under `src/pages` and keep JSON-LD accurate.
- Ads: Worker routes `/api/ads`, `/api/ads/intent`, `/api/ads/webhook`. Min bid 5 USDC.

## Commands

```
npm run validate
npm run build
```

## Do not

- Invent contract addresses.
- Claim listings are audited or official Uniswap routing.
- Commit `.dev.vars` or secrets.
