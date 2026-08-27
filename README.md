# v4hooks — Uniswap v4 hooks you can build

**[v4hooks.com](https://v4hooks.com)** — a builder cookbook for Uniswap v4 hooks.

Licensed Solidity excerpts. GitHub permalinks. Permissions bits. Callbacks you can actually read. Built for humans *and* agents.

Every listing shows the `getHookPermissions` block and the callbacks that matter, so you can see which of the 14 permission bits a hook lights up before you copy anything into Foundry.

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

## In the catalog

[LP management](https://v4hooks.com/categories/lp-management) · [Dynamic fees](https://v4hooks.com/categories/dynamic-fees) · [Limit orders](https://v4hooks.com/categories/limit-orders) · [MEV protection](https://v4hooks.com/categories/mev-protection) · [Wrappers](https://v4hooks.com/categories/wrappers) · [Launchpads](https://v4hooks.com/categories/launchpads) · [Lending](https://v4hooks.com/categories/lending) · [TWAMM](https://v4hooks.com/categories/twamm) · [Vote-escrow](https://v4hooks.com/categories/ve) · [Compliance](https://v4hooks.com/categories/compliance) · [Creator economy](https://v4hooks.com/categories/creator-economy) · [Oracles](https://v4hooks.com/categories/oracles) · [RWA](https://v4hooks.com/categories/rwa)

Includes AntiSandwichHook, BaseHook, LimitOrderHook, LiquidityPenaltyHook, ReHypothecationHook, TWAMM, Geomean oracle, Volatility oracle, Stop-loss, Take profits, Full range, veLP and the hooks behind Clanker, EulerSwap, Flaunch and Super DCA.

---

## Browse

- Site → [v4hooks.com](https://v4hooks.com)
- Learn → [v4hooks.com/learn](https://v4hooks.com/learn) — [What is a v4 hook?](https://v4hooks.com/learn/what-is-a-uniswap-v4-hook) · [Secure v4 hooks](https://v4hooks.com/learn/secure-v4-hooks) · [OpenZeppelin hooks](https://v4hooks.com/learn/openzeppelin-hooks)
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
