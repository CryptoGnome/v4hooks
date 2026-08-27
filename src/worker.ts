export interface Env {
  DB: D1Database;
  ASSETS: Fetcher;
  HELIO_PAYLINK_ID?: string;
  HELIO_WEBHOOK_SECRET?: string;
  TURNSTILE_SECRET?: string;
  DEV_PAY_SECRET?: string;
}

const MIN_CENTS = 500;
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, x-helio-signature",
};

type Ad = {
  id: string;
  name: string;
  url: string;
  tagline: string;
  logo: string | null;
  bid_cents: number;
  status: string;
  tx_hash: string | null;
  chain: string | null;
  created_at: number;
  updated_at: number;
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") return new Response(null, { headers: CORS });
    if (!url.pathname.startsWith("/api/")) {
      return env.ASSETS.fetch(request);
    }
    try {
      if (url.pathname === "/api/ads" && request.method === "GET") return json(await listLive(env));
      if (url.pathname === "/api/ads/intent" && request.method === "POST") return intent(request, env);
      if (url.pathname === "/api/ads/webhook" && request.method === "POST") return webhook(request, env);
      if (url.pathname === "/api/ads/dev-pay" && request.method === "POST") return devPay(request, env);
      return json({ error: "not found" }, 404);
    } catch (err) {
      const message = err instanceof Error ? err.message : "server error";
      return json({ error: message }, 400);
    }
  },
};

async function listLive(env: Env) {
  const { results } = await env.DB.prepare(
    "SELECT * FROM ads WHERE status = 'live' ORDER BY bid_cents DESC, created_at ASC",
  ).all<Ad>();
  return {
    min_usdc: MIN_CENTS / 100,
    listings: (results ?? []).map((row, i) => serialize(row, i + 1)),
  };
}

async function intent(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>();
  const name = cleanName(String(body.name ?? ""));
  const url = cleanUrl(String(body.url ?? ""));
  const tagline = cleanTagline(String(body.tagline ?? ""));
  const logo = body.logo ? cleanUrl(String(body.logo)) : null;
  const bidCents = Math.round(Number(body.bid_usdc) * 100);
  if (!Number.isFinite(bidCents) || bidCents < MIN_CENTS) {
    throw new Error(`Minimum bid is ${MIN_CENTS / 100} USDC`);
  }

  const existing = await env.DB.prepare(
    "SELECT * FROM ads WHERE url = ? AND status = 'live'",
  )
    .bind(url)
    .first<Ad>();
  const chargeCents = existing ? bidCents - existing.bid_cents : bidCents;
  if (existing && chargeCents < 100) {
    throw new Error("Raise must be at least 1 USDC above your current bid");
  }

  const top = await env.DB.prepare(
    "SELECT bid_cents FROM ads WHERE status = 'live' ORDER BY bid_cents DESC LIMIT 1",
  ).first<{ bid_cents: number }>();
  const id = crypto.randomUUID();
  const now = Date.now();
  await env.DB.prepare(
    `INSERT INTO ads (id, name, url, tagline, logo, bid_cents, status, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, 'pending', ?, ?)`,
  )
    .bind(id, name, url, tagline, logo, bidCents, now, now)
    .run();

  return json({
    id,
    charge_usdc: chargeCents / 100,
    total_bid_usdc: bidCents / 100,
    paylink_id: env.HELIO_PAYLINK_ID ?? null,
    would_be_first: !top || bidCents > top.bid_cents,
  });
}

async function webhook(request: Request, env: Env) {
  const raw = await request.text();
  if (env.HELIO_WEBHOOK_SECRET) {
    const sent = request.headers.get("authorization") || request.headers.get("x-helio-signature") || "";
    if (!sent.includes(env.HELIO_WEBHOOK_SECRET)) throw new Error("bad webhook secret");
  }
  const payload = JSON.parse(raw) as Record<string, unknown>;
  const meta = extractPayment(payload);
  if (!meta.id) throw new Error("missing bid id");
  const row = await env.DB.prepare("SELECT * FROM ads WHERE id = ?").bind(meta.id).first<Ad>();
  if (!row) throw new Error("unknown bid");
  await activate(env, row, meta.tx, meta.chain);
  return json({ ok: true });
}

async function devPay(request: Request, env: Env) {
  if (!env.DEV_PAY_SECRET) throw new Error("dev pay disabled");
  const body = await request.json<{ secret?: string; id?: string }>();
  if (body.secret !== env.DEV_PAY_SECRET) throw new Error("bad secret");
  const row = await env.DB.prepare("SELECT * FROM ads WHERE id = ?").bind(body.id).first<Ad>();
  if (!row) throw new Error("unknown bid");
  await activate(env, row, "dev", "dev");
  return json({ ok: true });
}

async function activate(env: Env, pending: Ad, tx: string | null, chain: string | null) {
  const now = Date.now();
  const live = await env.DB.prepare("SELECT * FROM ads WHERE url = ? AND status = 'live'")
    .bind(pending.url)
    .first<Ad>();
  if (live) {
    await env.DB.prepare(
      "UPDATE ads SET name = ?, tagline = ?, logo = ?, bid_cents = ?, tx_hash = ?, chain = ?, updated_at = ? WHERE id = ?",
    )
      .bind(pending.name, pending.tagline, pending.logo, pending.bid_cents, tx, chain, now, live.id)
      .run();
    await env.DB.prepare("DELETE FROM ads WHERE id = ?").bind(pending.id).run();
    return;
  }
  await env.DB.prepare(
    "UPDATE ads SET status = 'live', tx_hash = ?, chain = ?, updated_at = ? WHERE id = ?",
  )
    .bind(tx, chain, now, pending.id)
    .run();
}

function extractPayment(payload: Record<string, unknown>) {
  const extra =
    (payload.additionalJSON as string) ||
    nested(payload, ["transactionObject", "meta", "additionalJSON"]) ||
    nested(payload, ["meta", "additionalJSON"]) ||
    "";
  let parsed: Record<string, string> = {};
  try {
    parsed = extra ? (JSON.parse(extra) as Record<string, string>) : {};
  } catch {
    parsed = {};
  }
  return {
    id: String(payload.bidId ?? parsed.bidId ?? payload.id ?? ""),
    tx:
      String(
        payload.transactionSignature ??
          nested(payload, ["transactionObject", "meta", "transactionSignature"]) ??
          "",
      ) || null,
    chain: String(payload.chain ?? nested(payload, ["transactionObject", "meta", "network"]) ?? "") || null,
  };
}

function nested(obj: unknown, path: string[]): string | undefined {
  let cur: unknown = obj;
  for (const key of path) {
    if (!cur || typeof cur !== "object") return undefined;
    cur = (cur as Record<string, unknown>)[key];
  }
  return typeof cur === "string" ? cur : undefined;
}

function serialize(row: Ad, rank: number) {
  return {
    rank,
    name: row.name,
    url: row.url,
    tagline: row.tagline,
    logo: row.logo,
    bid_usdc: row.bid_cents / 100,
    chain: row.chain,
    updated_at: row.updated_at,
  };
}

function cleanName(s: string) {
  const v = s.trim().slice(0, 80);
  if (v.length < 2) throw new Error("name required");
  return v;
}

function cleanTagline(s: string) {
  const v = s.trim().slice(0, 160);
  if (v.length < 8) throw new Error("tagline required");
  return v;
}

function cleanUrl(s: string) {
  const u = new URL(s.trim());
  if (u.protocol !== "https:") throw new Error("https url required");
  u.search = "";
  u.hash = "";
  return u.toString().replace(/\/$/, "");
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", ...CORS },
  });
}
