export const SITE = {
  name: "v4hooks",
  url: "https://v4hooks.com",
  tagline: "Uniswap v4 hooks you can build",
  description:
    "Example Uniswap v4 hook contracts and Solidity snippets for agents and builders. Not Uniswap’s on-chain address registry.",
};

export const FLAG_ORDER = [
  "beforeInitialize",
  "afterInitialize",
  "beforeAddLiquidity",
  "afterAddLiquidity",
  "beforeRemoveLiquidity",
  "afterRemoveLiquidity",
  "beforeSwap",
  "afterSwap",
  "beforeDonate",
  "afterDonate",
  "beforeSwapReturnDelta",
  "afterSwapReturnDelta",
  "afterAddLiquidityReturnDelta",
  "afterRemoveLiquidityReturnDelta",
] as const;

export type Flag = (typeof FLAG_ORDER)[number];

export const BIT_GROUPS: { id: string; label: string; flags: Flag[] }[] = [
  { id: "init", label: "Initialize", flags: ["beforeInitialize", "afterInitialize"] },
  {
    id: "liq",
    label: "Liquidity",
    flags: ["beforeAddLiquidity", "afterAddLiquidity", "beforeRemoveLiquidity", "afterRemoveLiquidity"],
  },
  { id: "swap", label: "Swap", flags: ["beforeSwap", "afterSwap"] },
  { id: "donate", label: "Donate", flags: ["beforeDonate", "afterDonate"] },
  {
    id: "delta",
    label: "Return delta",
    flags: [
      "beforeSwapReturnDelta",
      "afterSwapReturnDelta",
      "afterAddLiquidityReturnDelta",
      "afterRemoveLiquidityReturnDelta",
    ],
  },
];

export const PROPERTIES = [
  { slug: "dynamic-fee", name: "Dynamic fee", blurb: "Pool fee can change via the hook (OVERRIDE_FEE / dynamic fee flag)." },
  { slug: "upgradeable", name: "Upgradeable", blurb: "Hook logic sits behind a proxy or otherwise upgradeable deployment." },
  { slug: "custom-swap-data", name: "Custom swap data", blurb: "Swaps need encoded hookData (or a custom router), not a bare vanilla swap." },
  { slug: "vanilla-swap", name: "Vanilla swap", blurb: "Works with a normal swap path; no special hookData required to trade." },
] as const;

export type PropertySlug = (typeof PROPERTIES)[number]["slug"];

export const CATEGORIES = [
  { slug: "dynamic-fees", name: "Dynamic fees", blurb: "Fees that move with volatility, volume, or loyalty." },
  { slug: "limit-orders", name: "Limit orders", blurb: "Onchain orders that fill at a tick." },
  { slug: "twamm", name: "TWAMM", blurb: "Time-weighted execution for large flow." },
  { slug: "launchpads", name: "Launchpads", blurb: "Token launches that settle into v4 pools." },
  { slug: "oracles", name: "Oracles", blurb: "Pools that also publish a price." },
  { slug: "ve", name: "Vote-escrow", blurb: "ve-style gauges and directed emissions." },
  { slug: "rwa", name: "RWA", blurb: "Compliant or real-world asset pools." },
  { slug: "mev-protection", name: "MEV protection", blurb: "Defenses for LPs and swappers against toxic flow." },
  { slug: "lp-management", name: "LP management", blurb: "Rebalancing, rehypothecation, and position managers." },
  { slug: "lending", name: "Lending", blurb: "Idle liquidity routed into lending markets." },
  { slug: "wrappers", name: "Wrappers", blurb: "Native ETH, WETH, and token adapter hooks." },
  { slug: "creator-economy", name: "Creator economy", blurb: "Creator coins, fees, and buybacks." },
  { slug: "auctions", name: "Auctions", blurb: "Auction-managed AMMs and sequencing." },
  { slug: "compliance", name: "Compliance", blurb: "KYC, allowlists, and jurisdictional checks." },
  { slug: "gaming", name: "Gaming", blurb: "Games and NFTs that live inside a hook." },
] as const;

export type CategorySlug = (typeof CATEGORIES)[number]["slug"];

export const CHAINS = [
  { slug: "ethereum", name: "Ethereum", id: 1 },
  { slug: "unichain", name: "Unichain", id: 130 },
  { slug: "base", name: "Base", id: 8453 },
  { slug: "arbitrum", name: "Arbitrum", id: 42161 },
  { slug: "optimism", name: "Optimism", id: 10 },
  { slug: "polygon", name: "Polygon", id: 137 },
  { slug: "blast", name: "Blast", id: 81457 },
  { slug: "worldchain", name: "World Chain", id: 480 },
  { slug: "avalanche", name: "Avalanche", id: 43114 },
  { slug: "bnb", name: "BNB Chain", id: 56 },
  { slug: "celo", name: "Celo", id: 42220 },
  { slug: "zora", name: "Zora", id: 7777777 },
  { slug: "ink", name: "Ink", id: 57073 },
  { slug: "soneium", name: "Soneium", id: 1868 },
  { slug: "linea", name: "Linea", id: 59144 },
  { slug: "monad", name: "Monad", id: 143 },
  { slug: "robinhood", name: "Robinhood Chain", id: 202599 },
  { slug: "megaeth", name: "MegaETH", id: 4326 },
  { slug: "tempo", name: "Tempo", id: 4217 },
  { slug: "xlayer", name: "X Layer", id: 196 },
  { slug: "zksync", name: "zkSync", id: 324 },
] as const;

export type ChainSlug = (typeof CHAINS)[number]["slug"];

export const CHAIN_SLUGS = new Set(CHAINS.map((c) => c.slug));
export const CATEGORY_SLUGS = new Set(CATEGORIES.map((c) => c.slug));
export const PROPERTY_SLUGS = new Set(PROPERTIES.map((p) => p.slug));

export function chainBySlug(slug: string) {
  return CHAINS.find((c) => c.slug === slug);
}

export function categoryBySlug(slug: string) {
  return CATEGORIES.find((c) => c.slug === slug);
}

export function propertyBySlug(slug: string) {
  return PROPERTIES.find((p) => p.slug === slug);
}

export type Deployment = {
  chain: string;
  address: string;
  hooklist?: boolean;
};

export type HookSource = {
  url: string;
  repo: string;
  path?: string;
};

export type Hook = {
  slug: string;
  name: string;
  kind: "pattern" | "product";
  tagline: string;
  description: string;
  source: HookSource;
  solidity: string;
  categories: CategorySlug[];
  chains: string[];
  deployments?: Deployment[];
  docs?: string;
  website?: string;
  audit_url?: string;
  license: string;
  flags: Flag[];
  properties: PropertySlug[];
  status: "production" | "experimental" | "deprecated";
  added: string;
  updated: string;
};
