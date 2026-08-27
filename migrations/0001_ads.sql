-- Pending checkout rows + live ranked sponsor listings.
CREATE TABLE IF NOT EXISTS ads (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  url TEXT NOT NULL,
  tagline TEXT NOT NULL,
  logo TEXT,
  bid_cents INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  tx_hash TEXT,
  chain TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ads_url ON ads(url);
CREATE INDEX IF NOT EXISTS idx_ads_live ON ads(status, bid_cents DESC, created_at ASC);
