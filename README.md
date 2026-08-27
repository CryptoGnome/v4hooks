# v4hooks

Curated directory of **Uniswap v4 hooks you can use**. Site: [v4hooks.com](https://v4hooks.com).

This is not Uniswap’s official registry. [Uniswap/hooklist](https://github.com/Uniswap/hooklist) is the address book (bytecode at an address, per chain). v4hooks is the product index: one listing per hook you might actually pick, with categories, chains, audits, and agent files.

## Use the catalog

- Browse: https://v4hooks.com
- Agents: https://v4hooks.com/llms.txt · [llm-full.txt](https://v4hooks.com/llm-full.txt) · [hooks.json](https://v4hooks.com/hooks.json)
- Skill: [SKILLS.md](SKILLS.md)
- Source: https://github.com/CryptoGnome/v4hooks

Listing a hook is not an audit, allowlist, or routing guarantee.

## Add a hook

1. Copy an existing file in [`hooks/`](hooks/).
2. Follow [`schema/hook.schema.json`](schema/hook.schema.json). Filename must match `slug`.
3. Open a pull request. CI must pass. A maintainer merges.

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Develop

```bash
npm install
npm run validate
npm run dev
```

Build and deploy to Cloudflare Workers (static pages + `/api/*` for the USDC bid board):

```bash
npm run deploy
```

Set Worker secrets for live ads: `HELIO_PAYLINK_ID`, `HELIO_WEBHOOK_SECRET`. Copy `.dev.vars.example` to `.dev.vars` for local `wrangler dev`.

## Stack

Astro static site, Cloudflare Workers assets, D1 for the outbid rail, GitHub Actions for validate + deploy.
