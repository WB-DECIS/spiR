---
date: 2026-04-11
title: "Inventory cache system"
status: completed
completed-date: 2026-04-11
scope: "Standard"
brainstorm: ".cg-docs/brainstorms/2026-04-11-inventory-cache-system.md"
language: "R"
estimated-effort: "medium"
tags: [cache, inventory, github-api, milestone-2]
---

# Plan: Inventory Cache System

## Objective

Build a persistent on-disk cache layer that stores the crawled GitHub file
tree for each SPI version (branch). The cache avoids redundant GitHub API
calls, pre-enriches file entries with `pillar`, `dimension`, and `category`
metadata parsed from file paths, and provides `spi_update_inventory()` to
force a refresh and `spi_clear_inventory()` to wipe cached files.

## Context

The spiR package (Milestone 1 complete) currently downloads the three core
output CSVs via `spi_download()` with an in-session environment cache
(`.spi_cache`). Milestone 2 adds inventory/discovery functions that need to
crawl the full worldbank/SPI directory tree.  Re-crawling on every call is
slow and wasteful — this feature stores the tree on disk in
`tools::R_user_dir("spiR", "cache")` with a 30-day TTL.

**Dependency:** The cache system consumes output from the GitHub tree
crawler (feature `github-tree-crawler`, not yet built). This plan defines
the expected interface: a function `.spi_crawl_tree(version)` returning a
`data.table(path, type, size)`. The cache system can be built and tested
with a mock of that function; wiring to the real crawler happens when that
feature is implemented.

### Key decisions (from brainstorm)

- **Approach A**: enrich metadata (pillar, dimension, category) at crawl
  time, not at query time.
- One RDS file per version, stored at
  `tools::R_user_dir("spiR", "cache")/tree_{version}.rds`.
- 30-day TTL; manual refresh via `spi_update_inventory()`.
- Incompatible/corrupt cache: warn user, delete, re-fetch.
- No-network + no-cache: informative error.
- Separate from the in-session download cache (`spi_clear_cache()`).

## Requirements

| ID  | Requirement                                                    | Source      |
|-----|----------------------------------------------------------------|-------------|
| R1  | Cache location: `tools::R_user_dir("spiR", "cache")`          | brainstorm  |
| R2  | One cache file per version: `tree_{version}.rds`               | brainstorm  |
| R3  | RDS contains `list(schema_version, timestamp, tree)`           | brainstorm  |
| R4  | `tree` is a `data.table` with `path, type, size, pillar, dimension, category` | brainstorm |
| R5  | TTL: 30 days from `timestamp`; expired cache triggers re-crawl | brainstorm  |
| R6  | `spi_update_inventory(version)`: force re-crawl and cache write | brainstorm |
| R7  | `spi_clear_inventory(version)`: delete on-disk cache files     | brainstorm  |
| R8  | No-network + no-cache → error with clear message               | brainstorm  |
| R9  | Incompatible schema → warn, delete, re-fetch                   | brainstorm  |
| R10 | Corrupted RDS → warn, delete, re-fetch                        | brainstorm  |
| R11 | Category derived from top-level folder: `raw`, `output`, `misc` | research   |
| R12 | Pillar derived from folder name (e.g., `1.1_DUNL` → pillar 1) | research    |
| R13 | Dimension derived from folder name (e.g., `5.2_Infrastructure` → `"5.2"`) | research |
| R14 | Non-enrichable paths get `NA` for pillar/dimension             | design      |

## Implementation Steps

### 1. Path-enrichment logic

- **Requirements**: R4, R11, R12, R13, R14
- **Files**: create `R/spi-inventory-cache.R`
- **Details**:
  Define `.spi_enrich_tree(tree_dt)` that takes a raw `data.table(path,
  type, size)` and adds three columns:
  - `category`: `"raw"` if path starts with `01_raw_data/`, `"output"` if
    `03_output_data/`, `"misc"` otherwise.
  - `pillar`: integer 1–5 extracted from the first subfolder name that
    starts with a digit (e.g., `01_raw_data/4.1_SOCS/...` → `4L`). `NA`
    for paths that don't match.
  - `dimension`: character `"P.D"` from the same subfolder (e.g.,
    `4.1_SOCS` → `"4.1"`). `NA` for paths that don't match.
  The function must be pure (no side effects) and rely only on the `path`
  column.
- **Test Scenarios**:
  - ✅ Raw data path → correct category/pillar/dimension
  - ✅ Output data path → `category = "output"`, `pillar = NA`, `dimension = NA`
  - ✅ Root-level file (e.g., `README.md`) → `category = "misc"`, pillar/dimension `NA`
  - ✅ Pillar 3 folder (`3_DP/2024/...`) → `pillar = 3`, `dimension = NA`
    (dimension subfolder doesn't match `P.D` pattern)
  - 🛑 Path with unexpected format → returns `NA`s without error
- **Tests**: `test-spi-inventory-cache.R` — `describe("path enrichment", ...)`
- **Acceptance criteria**: `.spi_enrich_tree()` returns a `data.table` with
  exactly 6 columns; all pillar/dimension values are correct for known SPI
  repo structure.

### 2. Cache read/write infrastructure

- **Requirements**: R1, R2, R3, R5, R9, R10
- **Files**: add to `R/spi-inventory-cache.R`
- **Details**:
  - `INVENTORY_CACHE_SCHEMA_VERSION <- 1L` — module-level constant.
  - `.spi_cache_dir()` → `tools::R_user_dir("spiR", "cache")`.  Creates
    the directory if it doesn't exist.
  - `.spi_cache_path(version)` → `file.path(.spi_cache_dir(),
    paste0("tree_", version, ".rds"))`.
  - `.spi_write_cache(tree_dt, version)` — calls `.spi_enrich_tree()`,
    wraps result in `list(schema_version = INVENTORY_CACHE_SCHEMA_VERSION,
    timestamp = Sys.time(), tree = enriched_dt)`, saves via `saveRDS()`.
  - `.spi_read_cache(version)` — reads RDS, validates:
    1. File exists? If not, return `NULL`.
    2. `readRDS()` succeeds? If not → warn, delete, return `NULL` (R10).
    3. Has `schema_version`, `timestamp`, `tree` names? If not → warn,
       delete, return `NULL`.
    4. `schema_version == INVENTORY_CACHE_SCHEMA_VERSION`? If not → warn
       (`cli::cli_warn`), delete, return `NULL` (R9).
    5. `difftime(Sys.time(), timestamp, units = "days") <= 30`? If expired,
       return `NULL` (caller will re-fetch).
    6. Return the `tree` `data.table`.
- **Test Scenarios**:
  - ✅ Round-trip: write then read returns identical `data.table`
  - ✅ Expired cache (timestamp > 30 days ago) returns `NULL`
  - 🛑 Corrupted file (not valid RDS) → warn + delete + `NULL`
  - 🛑 Wrong schema version → warn + delete + `NULL`
  - 🛑 Missing fields in the list → warn + delete + `NULL`
  - ❌ Non-existent file → `NULL`, no warning
- **Tests**: `test-spi-inventory-cache.R` — `describe("cache read/write", ...)`
- **Acceptance criteria**: all cache states (valid, expired, corrupt,
  incompatible, missing) handled correctly with no unhandled errors.

### 3. `spi_get_inventory()` internal resolver

- **Requirements**: R5, R8
- **Files**: add to `R/spi-inventory-cache.R`
- **Details**:
  Define `.spi_get_inventory(version = "master")`:
  1. Call `.spi_read_cache(version)`.
  2. If valid cache returned → return it.
  3. If `NULL` (missing, expired, corrupt):
     a. Try to crawl: call `.spi_crawl_tree(version)` (from the tree
        crawler feature).
     b. If crawl succeeds → call `.spi_write_cache(tree_dt, version)` →
        return the enriched `data.table`.
     c. If crawl fails (no network) → R8 applies: error "No cached
        inventory found — connect to the internet and try again."
  This function is the single entry point for any consumer that needs the
  inventory tree (e.g., future `spi_inventory()`, `spi_get_raw()`).
- **Test Scenarios**:
  - ✅ Cache hit → returns cached tree, no crawl call
  - ✅ Cache miss → calls crawler, writes cache, returns tree
  - ✅ Expired cache → calls crawler, overwrites
  - ❌ No cache + no network → informative error (R8)
- **Tests**: `test-spi-inventory-cache.R` — `describe("inventory resolver", ...)`
- **Acceptance criteria**: `.spi_get_inventory()` returns a `data.table` on
  success or errors clearly on failure; crawler is called only when needed.

### 4. Exported functions: `spi_update_inventory()` and `spi_clear_inventory()`

- **Requirements**: R6, R7
- **Files**: add to `R/spi-inventory-cache.R`; update roxygen2 → NAMESPACE
- **Details**:
  - `spi_update_inventory(version = "master")` — exported.
    1. Validate `version` (same pattern as `spi_download()`).
    2. Call `.spi_crawl_tree(version)`.
    3. Call `.spi_write_cache(tree_dt, version)`.
    4. `cli::cli_inform("Inventory updated for version {.val {version}}.")`
    5. Return the enriched `data.table` invisibly.
  - `spi_clear_inventory(version = NULL)` — exported.
    - If `version` is given: delete that one file.
    - If `version` is `NULL`: delete all `tree_*.rds` files in cache dir.
    - `cli::cli_inform()` confirmation message.
    - Return `NULL` invisibly.
  Full roxygen2 documentation for both functions.
- **Test Scenarios**:
  - ✅ `spi_update_inventory()` calls crawler, writes new cache
  - ✅ `spi_clear_inventory("master")` deletes only `tree_master.rds`
  - ✅ `spi_clear_inventory()` (no arg) deletes all tree files
  - 🛑 `spi_clear_inventory()` on empty cache dir → no error
  - ❌ `spi_update_inventory()` with bad version → input validation error
- **Tests**: `test-spi-inventory-cache.R` — `describe("exported functions", ...)`
- **Acceptance criteria**: both functions work, are documented, and appear
  in `NAMESPACE` after `devtools::document()`.

### 5. Wire up & integration test

- **Requirements**: all
- **Files**: update `tests/testthat/test-spi-inventory-cache.R`
- **Details**:
  Write an integration-style test (still mocked — no real network) that
  exercises the full lifecycle:
  1. Clear inventory.
  2. Call `.spi_get_inventory()` → cache miss → crawl → write → return.
  3. Call `.spi_get_inventory()` again → cache hit → no crawl.
  4. Call `spi_update_inventory()` → force crawl → overwrite.
  5. Call `spi_clear_inventory()` → files deleted.
  6. Call `.spi_get_inventory()` with crawl mocked to fail → error (R8).

  Use `withr::local_tempdir()` to override the cache directory in tests
  (mock `.spi_cache_dir()` to return the temp dir) so tests don't pollute
  the real user cache.
- **Test Scenarios**:
  - ✅ Full lifecycle sequence
  - ✅ Two different versions cached simultaneously
- **Tests**: `test-spi-inventory-cache.R` — `describe("lifecycle", ...)`
- **Acceptance criteria**: all lifecycle scenarios pass; no files left in
  real cache dir after tests.

## Testing Strategy

- All tests are **unit tests** — the GitHub tree crawler is mocked via
  `local_mocked_bindings(.spi_crawl_tree = ...)`.
- Cache directory is isolated with `withr::local_tempdir()`.
- Test data: small `data.table` with ~10 representative paths covering
  raw/output/misc and multiple pillars/dimensions.
- BDD-style with `describe()/it()` blocks, consistent with existing tests.
- Aim for full coverage of all 14 requirements.

## Documentation Checklist

- [x] `spi_update_inventory()` roxygen2 with `@export`, `@param`,
  `@return`, `@examples`, `@seealso`
- [x] `spi_clear_inventory()` roxygen2 with same
- [x] Internal functions: `@keywords internal` + `@param`/`@return`
- [ ] README update (deferred to Milestone 3 / documentation milestone)
- [x] Inline comments for path-enrichment regex logic

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| SPI repo restructures folders, breaking path enrichment | Low | Medium | Schema version bump invalidates old caches automatically; unit tests cover known structure |
| `tools::R_user_dir()` not available (R < 4.0) | None | N/A | Package already requires `R >= 4.1.0` |
| Race condition: two R sessions write the same cache file | Very low | Low | `saveRDS` overwrites atomically on most OS; acceptable for a single-user package |

## Out of Scope

- The GitHub tree crawler itself (feature `github-tree-crawler`) — this
  plan assumes a `.spi_crawl_tree(version)` interface.
- `spi_inventory()` interactive/programmatic modes — those are separate
  features that will *consume* this cache system.
- `spi_get_raw()` — another consumer, separate feature.
- GitHub API authentication / token support.
- Multi-page GitHub API pagination (handled by the crawler, not the cache).
- Any changes to the existing in-session download cache (`spi_clear_cache()`).
