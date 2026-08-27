import fs from "node:fs";
import path from "node:path";
import { parse } from "yaml";
import type { Hook } from "./meta";
import { CATEGORIES, CHAINS, PROPERTIES } from "./meta";

const DIR = path.join(process.cwd(), "hooks");

export function loadHooks(): Hook[] {
  if (!fs.existsSync(DIR)) return [];
  const files = fs.readdirSync(DIR).filter((f) => /\.ya?ml$/.test(f) && !f.startsWith("_"));
  const hooks = files.map((file) => {
    const raw = fs.readFileSync(path.join(DIR, file), "utf8");
    const data = parse(raw) as Hook;
    if (!data?.slug) throw new Error(`${file} is missing slug`);
    return data;
  });
  return hooks.sort((a, b) => a.name.localeCompare(b.name));
}

export function getHook(slug: string) {
  return loadHooks().find((h) => h.slug === slug);
}

export function hooksForChain(chain: string) {
  return loadHooks().filter((h) => h.chains.includes(chain));
}

export function hooksForCategory(category: string) {
  return loadHooks().filter((h) => h.categories.includes(category as Hook["categories"][number]));
}

export function latestUpdate(hooks = loadHooks()) {
  return hooks.reduce((max, h) => (h.updated > max ? h.updated : max), "2026-08-27");
}

export function usedChains(hooks = loadHooks()) {
  const used = new Set(hooks.flatMap((h) => h.chains));
  return CHAINS.filter((c) => used.has(c.slug));
}

export function usedCategories(hooks = loadHooks()) {
  const used = new Set(hooks.flatMap((h) => h.categories));
  return CATEGORIES.filter((c) => used.has(c.slug));
}

export function hooksForProperty(property: string) {
  return loadHooks().filter((h) => h.properties.includes(property as Hook["properties"][number]));
}

export function usedProperties(hooks = loadHooks()) {
  const used = new Set(hooks.flatMap((h) => h.properties));
  return PROPERTIES.filter((p) => used.has(p.slug));
}

export function paragraph(text: string) {
  return text.replace(/\s+/g, " ").trim();
}
