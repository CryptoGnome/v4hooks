import fs from "node:fs";
import path from "node:path";
import { parse } from "yaml";
import Ajv from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

const root = process.cwd();
const schema = JSON.parse(fs.readFileSync(path.join(root, "schema/hook.schema.json"), "utf8"));
const ajv = new Ajv({ allErrors: true, strict: false });
addFormats(ajv);
const validate = ajv.compile(schema);

const CHAINS = new Set([
  "ethereum",
  "unichain",
  "base",
  "arbitrum",
  "optimism",
  "polygon",
  "blast",
  "worldchain",
  "avalanche",
  "bnb",
  "celo",
  "zora",
  "ink",
  "soneium",
  "linea",
  "monad",
  "robinhood",
  "megaeth",
  "tempo",
  "xlayer",
  "zksync",
]);

const dir = path.join(root, "hooks");
const files = fs.readdirSync(dir).filter((f) => /\.ya?ml$/.test(f) && !f.startsWith("_"));
if (!files.length) {
  console.error("no hook files");
  process.exit(1);
}

const slugs = new Set();
const addresses = new Set();
let errors = 0;

for (const file of files) {
  const raw = fs.readFileSync(path.join(dir, file), "utf8");
  const data = parse(raw);
  const ok = validate(data);
  const prefix = `hooks/${file}`;
  if (!ok) {
    errors += 1;
    console.error(prefix, validate.errors);
  }
  if (data?.slug && slugs.has(data.slug)) {
    errors += 1;
    console.error(prefix, "duplicate slug", data.slug);
  }
  slugs.add(data?.slug);
  if (data?.slug && file.replace(/\.ya?ml$/, "") !== data.slug) {
    errors += 1;
    console.error(prefix, "filename must match slug");
  }
  const src = data?.source?.url ?? "";
  if (src && !src.startsWith("https://github.com/")) {
    errors += 1;
    console.error(prefix, "source.url must be a GitHub permalink");
  }
  for (const chain of data?.chains ?? []) {
    if (!CHAINS.has(chain)) {
      errors += 1;
      console.error(prefix, "unknown chain", chain);
    }
  }
  for (const d of data?.deployments ?? []) {
    const key = `${d.chain}:${d.address.toLowerCase()}`;
    if (addresses.has(key)) {
      errors += 1;
      console.error(prefix, "duplicate deployment", key);
    }
    addresses.add(key);
    if (d.address !== d.address.toLowerCase()) {
      errors += 1;
      console.error(prefix, "address must be lowercase");
    }
    if (!data.chains.includes(d.chain)) {
      errors += 1;
      console.error(prefix, "deployment chain not listed in chains");
    }
  }
}

if (errors) {
  console.error(`failed with ${errors} error(s)`);
  process.exit(1);
}
console.log(`validated ${files.length} hooks`);
