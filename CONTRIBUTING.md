# Contributing to v4hooks

v4hooks is a directory of Uniswap v4 **products**, not a clone of Uniswap/hooklist. One YAML file per hook you would tell a friend to use. Group every chain deployment under that one file.

## Rules

- Filename `hooks/{slug}.yml` must match `slug`.
- `description` must be unique, at least 280 characters, and explain the job (not “this is a uniswap hook”).
- HTTPS only for `website`, `repo`, `docs`, `audit_url`.
- Chains must be in the allowlist in `scripts/validate.mjs`.
- Addresses lowercase `0x` + 40 hex. Do not invent addresses. Prefer omitting `deployments` over guessing.
- Do not duplicate an existing slug or the same chain+address pair.
- Status is `production`, `experimental`, or `deprecated`.
- Listing is not an audit. Do not claim Uniswap endorsement.

## Steps

1. Fork the repo.
2. Add or edit `hooks/{slug}.yml`.
3. Run `npm run validate`.
4. Open a PR with the template. A maintainer must merge. CI is directory-quality (schema, uniqueness, URLs), not a security review.

## What we will reject

- Raw hooklist dumps (one file per address with no product story).
- Thin pages, keyword stuffing, or copied Uniswap docs.
- Affiliate tracking query strings on URLs.
- Hooks you cannot point to a public repo, site, or docs.

## Advertise

Paid placement is the [sponsor rail](https://v4hooks.com/advertise), not a YAML file. Do not PR ads into `hooks/`.
