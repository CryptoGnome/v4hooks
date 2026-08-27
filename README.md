# v4hooks

Example **Uniswap v4 hook** contracts and Solidity snippets. Site: [v4hooks.com](https://v4hooks.com).

This is not Uniswap’s official registry. [Uniswap/hooklist](https://github.com/Uniswap/hooklist) is the address book. v4hooks is how to **build** a hook: `getHookPermissions`, the callbacks, a licensed excerpt, and a permalink to the full file.

- **pattern** — copy the source to implement the job (TWAMM, limit order, oracle, …).
- **product** — a live protocol’s hook, excerpted so you can see how they wired bits. Do not paste it as your factory.

## Use the catalog

- Browse: https://v4hooks.com
- Agents: https://v4hooks.com/llms.txt · [llm-full.txt](https://v4hooks.com/llm-full.txt) · [hooks.json](https://v4hooks.com/hooks.json)
- Skill: [SKILLS.md](SKILLS.md)
- Source: https://github.com/CryptoGnome/v4hooks

A listing is not an audit. “Confirmed” means we pointed at a real public file, not that you should deploy it with funds.

## Add a hook

1. Copy [`hooks/_template.yml`](hooks/_template.yml) to `hooks/{slug}.yml`. Filename must match `slug`.
2. Required: `kind`, `source.url` (GitHub permalink), `solidity` excerpt, `flags`, `license`. Follow [`schema/hook.schema.json`](schema/hook.schema.json).
3. Open a pull request. CI must pass. A maintainer merges.

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Develop

```bash
npm install
npm run validate
npm run dev
```

```bash
npm run deploy
```

Set Worker secrets for live ads: `HELIO_PAYLINK_ID`, `HELIO_WEBHOOK_SECRET`. Copy `.dev.vars.example` to `.dev.vars` for local `wrangler dev`.

## Stack

Astro static site, Cloudflare Workers assets, D1 for the outbid rail. Deploys via Cloudflare Workers Builds on push to `main`; GitHub Actions still runs validate.
