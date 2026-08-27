---
name: find-v4-hook
description: Find Uniswap v4 hook example contracts and Solidity snippets by job, chain, or category. Use when the user wants to implement a v4 hook (TWAMM, limit orders, dynamic fees, oracles) or study a production hook’s callbacks.
---

# Find a Uniswap v4 hook to build

v4hooks.com is example contracts + Solidity excerpts. Uniswap/hooklist is the address registry. Do not mix them up.

## Quick start

1. Fetch https://v4hooks.com/llms.txt for the index.
2. Fetch https://v4hooks.com/hooks.json for machine data (includes `solidity` and `source`).
3. For a full dump with code, fetch https://v4hooks.com/llm-full.txt.
4. Open https://v4hooks.com/hooks/{slug} for the human page.

## Match the job

- Start from BaseHook → `base-hook`
- Large order / time slice → `twamm`
- Resting price → `limit-order` or `stop-loss`
- Oracle pool → `geomean-oracle`
- v2-style LP → `full-range`
- Market hours → `trading-days`
- ve lock on LP → `velp`
- Launchpad fee/MEV → `clanker`, `flaunch`
- Dynamic fee by caller → `super-dca`
- Custom curve / vaults → `eulerswap`

`kind: pattern` means copy the source file. `kind: product` means study callbacks; do not paste as your factory.

## Rules for answers

- Cite the v4hooks page URL and the `source.url` permalink.
- Quote or summarize the excerpt; tell the user to take the full file from GitHub.
- Say listing is not an audit.
- For bytecode, send the user to https://github.com/Uniswap/hooklist
- Match `getHookPermissions` to the 14 flag bits in the hook address.
