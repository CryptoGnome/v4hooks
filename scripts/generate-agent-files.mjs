import fs from "node:fs";
import path from "node:path";
import { parse } from "yaml";

const root = process.cwd();
const dir = path.join(root, "hooks");
const site = "https://v4hooks.com";
const files = fs.readdirSync(dir).filter((f) => /\.ya?ml$/.test(f) && !f.startsWith("_"));
const hooks = files
  .map((file) => parse(fs.readFileSync(path.join(dir, file), "utf8")))
  .sort((a, b) => a.name.localeCompare(b.name));

const cats = [...new Set(hooks.flatMap((h) => h.categories))].sort();
const chains = [...new Set(hooks.flatMap((h) => h.chains))].sort();

const llms = `# v4hooks

> Example Uniswap v4 hook contracts and Solidity snippets for builders and agents. Not the official Uniswap hooklist address registry.

Site: ${site}
Catalog JSON: ${site}/hooks.json
Full dump: ${site}/llm-full.txt
Contribute: https://github.com/CryptoGnome/v4hooks (see CONTRIBUTING.md)

## Pages
- [${site}/](${site}/): Directory home
- [${site}/advertise](${site}/advertise): USDC bid board
- [${site}/learn/what-is-a-uniswap-v4-hook](${site}/learn/what-is-a-uniswap-v4-hook): Explainer
${cats.map((c) => `- [${site}/categories/${c}](${site}/categories/${c})`).join("\n")}
${chains.map((c) => `- [${site}/chains/${c}](${site}/chains/${c})`).join("\n")}

## Hooks
${hooks.map((h) => `- [${h.name}](${site}/hooks/${h.slug}) (${h.kind}): ${h.tagline}`).join("\n")}
`;

const full = `# v4hooks full catalog

${hooks
  .map((h) =>
    [
      `## ${h.name} (${h.slug})`,
      `Kind: ${h.kind}`,
      h.tagline,
      "",
      h.description.trim(),
      "",
      "### Solidity",
      "```solidity",
      h.solidity.trim(),
      "```",
      "",
      `Source: ${h.source.url}`,
      `Status: ${h.status}`,
      `License: ${h.license}`,
      `Categories: ${h.categories.join(", ")}`,
      `Chains: ${h.chains.join(", ")}`,
      `Flags: ${h.flags.join(", ")}`,
      h.website ? `Website: ${h.website}` : null,
      h.docs ? `Docs: ${h.docs}` : null,
      h.audit_url ? `Audit: ${h.audit_url}` : null,
      `Page: ${site}/hooks/${h.slug}`,
      (h.deployments ?? [])
        .map((d) => `- ${d.chain} ${d.address}${d.hooklist ? " (hooklist)" : ""}`)
        .join("\n") || null,
    ]
      .filter(Boolean)
      .join("\n"),
  )
  .join("\n\n")}
`;

const publicDir = path.join(root, "public");
fs.mkdirSync(publicDir, { recursive: true });
fs.writeFileSync(path.join(publicDir, "llms.txt"), llms);
fs.writeFileSync(path.join(publicDir, "llm-full.txt"), full);
fs.writeFileSync(path.join(publicDir, "hooks.json"), JSON.stringify({ generated: new Date().toISOString(), hooks }, null, 2));
console.log(`wrote llms.txt, llm-full.txt, hooks.json (${hooks.length} hooks)`);
