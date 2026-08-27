# v4hooks

A practical catalog of [Uniswap v4](https://docs.uniswap.org/contracts/v4/overview) hook patterns and production implementations.

Browse the catalog at **[v4hooks.com](https://v4hooks.com)**.

Each entry includes:

- a pinned GitHub source link
- a licensed Solidity excerpt
- the hook's permission flags
- the callbacks that define its behavior
- chain, category, deployment, audit, and license metadata when available

> [!WARNING]
> This catalog is not an audit. A confirmed source means the linked code exists; it does not mean the hook is safe to deploy with funds.

## Catalog

The catalog covers:

- dynamic fees and MEV protection
- limit orders, stop-losses, and take-profit orders
- liquidity management and launchpads
- TWAMMs, oracles, lending, and wrappers
- production hooks from projects such as Clanker, EulerSwap, Flaunch, and Zora
- first-party reference implementations maintained in this repository

Start with the [full catalog](https://v4hooks.com), browse by [category](https://v4hooks.com/categories/dynamic-fees), or read the [building guides](https://v4hooks.com/learn).

## Repository structure

| Path | Contents |
| --- | --- |
| [`hooks/`](hooks/) | Catalog records in YAML; the source of truth |
| [`contracts/`](contracts/) | First-party Solidity reference implementations |
| [`test/`](test/) | Foundry tests for first-party contracts |
| [`src/`](src/) | Astro site and Cloudflare Worker |
| [`schema/`](schema/) | JSON Schema for catalog records |
| [`scripts/`](scripts/) | Validation, generation, and catalog sync tools |

Generated machine-readable files:

- [`hooks.json`](https://v4hooks.com/hooks.json) — complete structured catalog
- [`llms.txt`](https://v4hooks.com/llms.txt) — compact index for agents
- [`llm-full.txt`](https://v4hooks.com/llm-full.txt) — full catalog for agents
- [`SKILLS.md`](SKILLS.md) — agent workflow for using the repository

## Add a hook

Copy the template, fill in the required metadata, and validate it:

```bash
cp hooks/_template.yml hooks/{slug}.yml
npm install
npm run validate
```

The filename must match `slug`, and `source.url` must point to a pinned public GitHub file. See [CONTRIBUTING.md](CONTRIBUTING.md) for the schema rules and review checklist.

## Development

Requirements:

- Node.js 22.12 or newer
- npm 10.8 or newer
- Foundry for Solidity builds and tests

```bash
nvm use
npm install
npm run validate
npm run build
forge build
forge test
```

Use `npm run dev` for the local site. Pushes to `main` deploy through Cloudflare Workers Builds; GitHub Actions validates the catalog and runs the Foundry suite.

For local ad API development, copy `.dev.vars.example` to `.dev.vars`. Production requires the `HELIO_PAYLINK_ID` and `HELIO_WEBHOOK_SECRET` Worker secrets.

## Stack

Astro, TypeScript, Solidity, Foundry, Cloudflare Workers, and D1.

## License and security

Catalog excerpts retain the licenses declared by their upstream sources. First-party code in this repository is covered by [LICENSE](LICENSE).

Report vulnerabilities according to [SECURITY.md](SECURITY.md).
