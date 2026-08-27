# v4hooks

**[v4hooks.com](https://v4hooks.com)** — a builder cookbook for Uniswap v4 hooks.

Licensed Solidity excerpts. GitHub permalinks. Permissions bits. Callbacks you can actually read. Built for humans *and* agents.

---

## What you get

| | |
|---|---|
| **Patterns** | Copyable implementations — TWAMM, limit orders, take-profit, oracles, dynamic fees, JIT penalty, rehypothecation, v2-on-v4, … |
| **Products** | How live protocols wire their hooks — study the callbacks, don’t paste the factory |
| **Agent dumps** | [`llms.txt`](https://v4hooks.com/llms.txt) · [`llm-full.txt`](https://v4hooks.com/llm-full.txt) · [`hooks.json`](https://v4hooks.com/hooks.json) |

Source of truth: `hooks/*.yml`. Each listing is a real public file + a licensed excerpt. Nothing invented.

> **Not an audit.** “Confirmed” means the source file exists in public. It does **not** mean safe to deploy with funds.

---

## Browse

- Site → [v4hooks.com](https://v4hooks.com)
- Learn → [v4hooks.com/learn](https://v4hooks.com/learn)
- Resources → [v4hooks.com/learn/resources](https://v4hooks.com/learn/resources)
- Agent skill → [`SKILLS.md`](SKILLS.md)
- Repo → [CryptoGnome/v4hooks](https://github.com/CryptoGnome/v4hooks)

---

## Add a listing

```bash
cp hooks/_template.yml hooks/{slug}.yml
# fill kind, source.url, solidity, flags, license
npm run validate
```

Filename must match `slug`. Schema: [`schema/hook.schema.json`](schema/hook.schema.json). Open a PR — CI must pass. Details in [`CONTRIBUTING.md`](CONTRIBUTING.md).

---

## Develop

```bash
npm install
npm run validate
npm run dev        # local site
npm run build      # Astro + agent files
npm run deploy     # build + wrangler (manual)
```

Push to `main` deploys via **Cloudflare Workers Builds**. GitHub Actions still runs validate.

For the ads rail, set Worker secrets `HELIO_PAYLINK_ID` and `HELIO_WEBHOOK_SECRET`. Local: copy `.dev.vars.example` → `.dev.vars`.

---

## Stack

Astro · Cloudflare Workers (assets + API) · D1 (`v4hooks-ads`) · Workers Builds on `main`
