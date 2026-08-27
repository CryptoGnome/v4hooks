// Proposes `deployments` and `audit_url` additions for existing listings, sourced from
// Uniswap/hooklist. Read-only by design: it prints a review list and never touches
// hooks/*.yml, because a name collision is not proof two contracts are the same thing
// (hooklist's "StarbaseHookV2" contains the substring "basehook").
//
//   node scripts/hooklist-sync.mjs            review list
//   node scripts/hooklist-sync.mjs --refresh  re-pull hooklist first
//   node scripts/hooklist-sync.mjs --all      include weak matches
//   node scripts/hooklist-sync.mjs --json     machine-readable proposals
//
// Evidence, in order of weight:
//   1. permission bits — the 14 flags are encoded in the deployed address, so an exact
//      match against a listing's `flags` is strong corroboration, and a near-match tells
//      you which deployed variant an excerpt corresponds to.
//   2. chain id — hooklist's chainId must agree with our CHAINS table.
//   3. name tokens — weakest, and only ever used to nominate candidates.

import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { parse } from "yaml";

const root = process.cwd();
const args = new Set(process.argv.slice(2));
const asJson = args.has("--json");
const showWeak = args.has("--all");

const REPO = "https://github.com/Uniswap/hooklist.git";
const cache = path.join(root, "node_modules/.cache/hooklist");

const log = (...m) => { if (!asJson) console.log(...m); };

function ensureHooklist() {
  const git = (cwd, ...a) => execFileSync("git", a, { cwd, stdio: "pipe" }).toString().trim();
  if (!fs.existsSync(path.join(cache, ".git"))) {
    log("cloning hooklist...");
    fs.mkdirSync(path.dirname(cache), { recursive: true });
    git(path.dirname(cache), "clone", "--depth", "1", "--quiet", REPO, cache);
  } else if (args.has("--refresh")) {
    log("refreshing hooklist...");
    git(cache, "fetch", "--depth", "1", "--quiet", "origin", "HEAD");
    git(cache, "reset", "--hard", "--quiet", "FETCH_HEAD");
  }
  return git(cache, "rev-parse", "--short", "HEAD");
}

// hooklist spells the four delta flags with an extra "s".
const FLAG_ALIASES = {
  beforeSwapReturnsDelta: "beforeSwapReturnDelta",
  afterSwapReturnsDelta: "afterSwapReturnDelta",
  afterAddLiquidityReturnsDelta: "afterAddLiquidityReturnDelta",
  afterRemoveLiquidityReturnsDelta: "afterRemoveLiquidityReturnDelta",
};

const schema = JSON.parse(fs.readFileSync(path.join(root, "schema/hook.schema.json"), "utf8"));
const FLAG_ORDER = schema.properties.flags.items.enum;
const ADDRESS_RE = new RegExp(schema.properties.deployments.items.properties.address.pattern);

// Chain slugs live in meta.ts; read them rather than keeping a second copy in sync.
const metaSrc = fs.readFileSync(path.join(root, "src/lib/meta.ts"), "utf8");
const chainsBlock = metaSrc.match(/export const CHAINS = \[([\s\S]*?)\] as const;/);
if (!chainsBlock) throw new Error("could not find CHAINS in src/lib/meta.ts");
const CHAIN_BY_SLUG = new Map(
  [...chainsBlock[1].matchAll(/slug:\s*"([a-z0-9-]+)",\s*name:\s*"[^"]*",\s*id:\s*(\d+)/g)]
    .map((m) => [m[1], Number(m[2])]),
);
if (CHAIN_BY_SLUG.size < 10) throw new Error(`only parsed ${CHAIN_BY_SLUG.size} chains from meta.ts`);

function loadHooklist() {
  const dir = path.join(cache, "hooks");
  const out = [];
  for (const chain of fs.readdirSync(dir)) {
    const chainDir = path.join(dir, chain);
    if (!fs.statSync(chainDir).isDirectory()) continue;
    for (const file of fs.readdirSync(chainDir)) {
      if (!file.endsWith(".json")) continue;
      const j = JSON.parse(fs.readFileSync(path.join(chainDir, file), "utf8"));
      const flags = Object.entries(j.flags ?? {})
        .filter(([, on]) => on)
        .map(([k]) => FLAG_ALIASES[k] ?? k)
        .filter((f) => FLAG_ORDER.includes(f));
      const onchain = flagsFromAddress(j.hook.address);
      const selfConsistent = onchain && onchain.length === flags.length && onchain.every((f) => flags.includes(f));
      // Trust the address, not the JSON — they agree in practice, but the address is proof.
      out.push({ ...j.hook, dirChain: chain, flags: onchain ?? flags, statedFlags: flags, selfConsistent });
    }
  }
  return out;
}

const STOP = new Set([
  "hook", "hooks", "uniswap", "v1", "v2", "v3", "v4", "the", "protocol",
  "finance", "pool", "pools", "fi", "xyz", "io", ...CHAIN_BY_SLUG.keys(),
]);

function tokenize(s) {
  return (s || "")
    .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
    .replace(/([A-Z]+)([A-Z][a-z])/g, "$1 $2")
    .split(/[^A-Za-z0-9]+/)
    .map((t) => t.toLowerCase())
    .filter(Boolean);
}
const distinctive = (s) => new Set(tokenize(s).filter((t) => !STOP.has(t) && t.length > 1));

// A shared word is only evidence if it is rare. "fee" appears in 17% of hooklist
// names and "base" in 9%, so matching on those means nothing; "flaunch" (9 of 576)
// or "twamm" (1) genuinely narrows it down. Anything at or below SPECIFIC_DF counts.
const SPECIFIC_DF = 25;

function documentFrequency(all) {
  const df = new Map();
  for (const e of all) for (const t of distinctive(e.name)) df.set(t, (df.get(t) ?? 0) + 1);
  return df;
}

function compareFlags(mine, theirs) {
  const missing = mine.filter((f) => !theirs.includes(f));
  const extra = theirs.filter((f) => !mine.includes(f));
  return { exact: !missing.length && !extra.length, missing, extra };
}

// v4 encodes the permission bits in the hook address itself: Hooks.sol assigns
// BEFORE_INITIALIZE to bit 13 down to AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA at bit 0,
// which is FLAG_ORDER in order. So the flags can be derived from the address by
// arithmetic alone — no RPC, and no need to trust hooklist's own JSON.
function flagsFromAddress(address) {
  const low = Number.parseInt(address.slice(-4), 16);
  if (!Number.isFinite(low)) return null;
  return FLAG_ORDER.filter((_, i) => (low >> (FLAG_ORDER.length - 1 - i)) & 1);
}

// ---------------------------------------------------------------------------

const head = ensureHooklist();
const entries = loadHooklist();
const DF = documentFrequency(entries);

const hooksDir = path.join(root, "hooks");
const listings = fs
  .readdirSync(hooksDir)
  .filter((f) => /\.ya?ml$/.test(f) && !f.startsWith("_"))
  .map((f) => parse(fs.readFileSync(path.join(hooksDir, f), "utf8")))
  .sort((a, b) => a.slug.localeCompare(b.slug));

log(`hooklist @ ${head} — ${entries.length} deployed hooks`);
log(`v4hooks — ${listings.length} listings\n`);

const proposals = [];

for (const listing of listings) {
  const mine = new Set([...distinctive(listing.name), ...distinctive(listing.slug)]);
  if (!mine.size) continue;

  const scored = [];
  for (const e of entries) {
    const theirs = distinctive(e.name);
    const shared = [...mine].filter((t) => theirs.has(t));
    if (!shared.length) continue;

    // Rank the shared words by how rare they are across all 576 hooklist names.
    const evidence = shared
      .map((t) => ({ token: t, df: DF.get(t) ?? 0 }))
      .sort((a, b) => a.df - b.df);
    const specific = evidence.filter((x) => x.df <= SPECIFIC_DF);
    if (!specific.length) continue; // only generic words in common — not evidence

    const bits = compareFlags(listing.flags, e.flags);
    const drift = bits.missing.length + bits.extra.length;
    const confidence = bits.exact ? "strong"
      : drift <= 2 ? "review"
      : "weak";
    scored.push({ e, bits, drift, evidence, confidence });
  }
  if (!scored.length) continue;

  const rank = { strong: 0, review: 1, weak: 2 };
  scored.sort((a, b) =>
    rank[a.confidence] - rank[b.confidence] ||
    a.evidence[0].df - b.evidence[0].df ||
    a.drift - b.drift);
  const keep = showWeak ? scored : scored.filter((s) => s.confidence !== "weak");
  if (!keep.length) continue;

  const CAP = 6;
  proposals.push({ listing, matches: keep.slice(0, CAP), suppressed: Math.max(0, keep.length - CAP) });
}

if (asJson) {
  console.log(JSON.stringify(
    proposals.map(({ listing, matches, suppressed }) => ({
      slug: listing.slug,
      hasDeployments: Boolean(listing.deployments?.length),
      hasAuditUrl: Boolean(listing.audit_url),
      suppressed,
      matches: matches.map((m) => ({
        name: m.e.name,
        chain: m.e.dirChain,
        address: m.e.address,
        auditUrl: m.e.auditUrl || null,
        confidence: m.confidence,
        matchedOn: m.evidence.map((x) => ({ token: x.token, df: x.df })),
        flagsExact: m.bits.exact,
        addressSelfConsistent: m.e.selfConsistent,
        flagsMissing: m.bits.missing,
        flagsExtra: m.bits.extra,
      })),
    })),
    null, 2,
  ));
  process.exit(0);
}

let strongCount = 0;
for (const { listing, matches, suppressed } of proposals) {
  const already = listing.deployments?.length ? "  (already has deployments)" : "";
  console.log(`\n${"─".repeat(72)}\n${listing.slug}${already}`);
  console.log(`  listing flags: ${listing.flags.join(", ")}`);

  for (const m of matches) {
    if (m.confidence === "strong") strongCount++;
    const chainOk = CHAIN_BY_SLUG.has(m.e.dirChain);
    const idOk = CHAIN_BY_SLUG.get(m.e.dirChain) === m.e.chainId;
    console.log(`\n  [${m.confidence}] ${m.e.name}`);
    console.log(`     chain    ${m.e.dirChain}${chainOk ? "" : "  UNKNOWN SLUG"}${idOk ? "" : `  chainId ${m.e.chainId} disagrees with meta.ts`}`);
    console.log(`     address  ${m.e.address}${ADDRESS_RE.test(m.e.address) ? "" : "  FAILS SCHEMA PATTERN"}`);
    console.log(`     bits     ${m.bits.exact ? "identical" : `missing:[${m.bits.missing.join(",")}] extra:[${m.bits.extra.join(",")}]`}  (derived from address)`);
    if (!m.e.selfConsistent) console.log("     WARNING  hooklist's stated flags disagree with the address bits");
    const ev = m.evidence.slice(0, 3).map((x) => `${x.token} (${x.df}/${entries.length})`).join(", ");
    console.log(`     matched  ${ev}`);
    if (m.e.auditUrl) console.log(`     audit    ${m.e.auditUrl}${listing.audit_url ? "  (listing already has one)" : ""}`);
  }

  if (suppressed) console.log(`
  ...${suppressed} further candidate(s) not shown`);

  const usable = matches.filter((m) => m.confidence === "strong" && CHAIN_BY_SLUG.has(m.e.dirChain));
  if (usable.length && !listing.deployments?.length) {
    console.log(`\n  paste into hooks/${listing.slug}.yml:`);
    console.log("    deployments:");
    for (const m of usable) {
      console.log(`      - chain: ${m.e.dirChain}`);
      console.log(`        address: "${m.e.address}"`);
      console.log("        hooklist: true");
    }
    const audit = usable.find((m) => m.e.auditUrl && !listing.audit_url);
    if (audit) console.log(`    audit_url: "${audit.e.auditUrl}"`);
  }
}

console.log(`\n${"─".repeat(72)}`);
console.log(`${proposals.length} listings with candidates, ${strongCount} strong match(es).`);
console.log("Nothing was written. Confirm each address really is that contract before pasting.");
