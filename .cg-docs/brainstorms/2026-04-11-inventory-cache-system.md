---
date: 2026-04-11
title: "Inventory cache system — per-version RDS with enriched metadata"
status: decided
scope: "Standard"
chosen-approach: "One RDS per version, enrich metadata at crawl time"
tags: [cache, inventory, github-api, milestone-2]
---

# Inventory Cache System

## Context

Milestone 2 ("Inventory & Raw Data") requires a cache layer for the GitHub
file tree so that `spi_inventory()` and `spi_get_raw()` don't re-crawl the
repository on every call. The cache stores the file tree metadata (paths,
sizes, types) — not file contents. It depends on the "GitHub tree crawler"
feature which fetches the tree via the GitHub API.

## Requirements

1. **Primary goal:** Avoid redundant GitHub API calls (performance
   optimization). Not an offline-first registry.
2. **Storage location:** `tools::R_user_dir("spiR", "cache")`.
3. **One cache per version:** Each branch gets its own file,
   `tree_{version}.rds`.
4. **RDS format:** Native R serialization — fast, compact, no extra
   dependencies.
5. **TTL:** 30 days. Cached trees auto-refresh when expired.
6. **Manual refresh:** `spi_update_inventory(version)` forces re-crawl and
   cache write, regardless of TTL.
7. **No network + no cache:** Clear error: "No cached inventory found —
   connect to the internet and try again."
8. **Corrupted / incompatible cache:** Warn user, delete bad file, re-fetch.
   Schema version integer in the RDS enables detection.
9. **Separate from download cache:** `spi_clear_cache()` clears only the
   in-session download cache. A new `spi_clear_inventory()` clears on-disk
   inventory cache files.
10. **No auth required:** Public repo, unauthenticated GitHub API.
11. **Cache stores metadata only:** `path`, `type` (blob/tree), `size`,
    plus pre-parsed `pillar`, `dimension`, `category` (raw/output/misc).

## Approaches Considered

### Approach A: One RDS per version, enrich metadata at crawl time

Each branch gets `tree_{version}.rds` containing
`list(schema_version, timestamp, tree)` where `tree` is a `data.table` with
columns `path`, `type`, `size`, `pillar`, `dimension`, `category` — all
derived from the file path at crawl time.

**Pros:**
- Fastest query time — `spi_inventory(pillar = 3)` is a simple
  `data.table` filter.
- Simple file management: delete one file to refresh one version.
- Schema version makes incompatibility detection trivial.

**Cons:**
- If path-parsing logic changes (new SPI repo folder structure), cached
  enrichments become wrong — requires schema version bump and re-crawl.
- Slightly more complex crawl step.

**Effort:** Small

### Approach B: One RDS per version, raw tree only, enrich at query time

Same file layout, but the cached `data.table` stores only raw API fields
(`path`, `type`, `size`). Pillar/dimension/category parsed on every
`spi_inventory()` call.

**Pros:**
- Cache never invalidated by parsing logic changes.
- Simpler cache format.

**Cons:**
- Unnecessary overhead on each query (~2000 paths).
- Parsing logic scattered across query paths.

**Effort:** Small

## Decision

**Approach A** — pre-parse metadata at crawl time. The SPI repo structure
is stable, so enrichments won't go stale frequently. Pre-parsing keeps
query paths clean and fast.

### Shared design elements

| Element | Design |
|---|---|
| Location | `tools::R_user_dir("spiR", "cache")` |
| File naming | `tree_{version}.rds` |
| TTL | 30 days from `timestamp` |
| Manual refresh | `spi_update_inventory(version = "master")` |
| No-network + no cache | Error with clear message |
| Corrupted/incompatible | Warn user, delete bad file, re-fetch |
| `spi_clear_cache()` | In-session download cache only |
| `spi_clear_inventory()` | On-disk inventory cache |
| Schema version | Integer in RDS; bump on format changes |

## Next Steps

1. Implement the GitHub tree crawler (feature `github-tree-crawler`) — this
   is a prerequisite. It should return the raw tree as a `data.table`.
2. Build path-enrichment logic: parse `pillar`, `dimension`, `category`
   from file paths in the SPI repo structure.
3. Implement cache read/write functions:
   - `spi_cache_path(version)` — resolves the RDS file path.
   - `spi_read_inventory_cache(version)` — reads + validates schema +
     checks TTL.
   - `spi_write_inventory_cache(tree_dt, version)` — writes with schema
     version and timestamp.
4. Implement `spi_update_inventory(version)` (exported) and
   `spi_clear_inventory(version)` (exported).
5. Wire the cache into `spi_inventory()` (the consumer, another feature).
6. Tests: cache hit, cache miss, TTL expiry, schema mismatch, corrupted
   file, no-network-no-cache error, `spi_clear_inventory()` behavior.
