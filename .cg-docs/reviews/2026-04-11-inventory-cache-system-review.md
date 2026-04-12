---
plan: .cg-docs/plans/2026-04-11-inventory-cache-system.md
fixed-by: fix(inventory): apply all review findings
findings:
  P1.1: fixed
  P1.2: fixed
  P2.1: fixed
  P2.2: fixed
  P2.3: fixed
  P2.4: fixed
  P2.5: fixed
  P2.6: fixed
  P2.7: fixed
  P2.8: fixed
  P2.9: fixed
  P2.10: fixed
  P2.11: fixed
  P2.12: fixed
  P3.1: fixed
  P3.2: fixed
  P3.3: fixed
  P3.4: fixed
  P3.5: fixed
  P3.6: fixed
  P3.7: fixed
  P3.8: fixed
  P3.9: fixed
  P3.10: fixed
  P3.11: fixed
  P3.12: fixed
  P3.13: fixed
  P3.14: fixed
---

## Review Report

**Review depth**: standard
**Files reviewed**: 4 (`R/spi-inventory-cache.R`, `tests/testthat/test-spi-inventory-cache.R`, `DESCRIPTION`, `NAMESPACE`)
**Findings**: 2 P1, 12 P2, 14 P3

---

### P1 — CRITICAL (must fix before merge)

- **[P1.1]** [cg-data-quality] `R/spi-inventory-cache.R` (`.spi_cache_path()`) — Path traversal vulnerability: `version` is concatenated into a file path and used in `unlink()` without sanitization.
  **Why**: `file.path(cache_dir, paste0("tree_", "../evil", ".rds"))` resolves outside the cache directory. The three `unlink(path)` calls in `.spi_read_cache()` (lines 195, 210, 215) would delete arbitrary files if an adversarial version string (`"../etc/passwd"`) were passed. `saveRDS()` in `.spi_write_cache()` could overwrite arbitrary files. OWASP A01 — broken access control / path traversal.
  **Fix**: Add a guard in `.spi_cache_path()`:
  ```r
  .spi_cache_path <- function(version) {
    if (grepl("[/\\\\]", version))
      cli::cli_abort("{.arg version} must not contain path separators; got {.val {version}}.")
    file.path(.spi_cache_dir(), paste0("tree_", version, ".rds"))
  }
  ```

- **[P1.2]** [cg-data-quality] `R/spi-inventory-cache.R` (`.spi_enrich_tree()`) — No input validation: missing `path` column produces a cryptic data.table length-mismatch error.
  **Why**: `dt[["path"]]` returns `NULL` when the column is absent. `rep("misc", length(NULL))` produces `character(0)`, and assigning a 0-length vector to an N-row data.table column throws an opaque error rather than an actionable one. Also no check that the input is a data.table.
  **Fix**: Add guards at the top of the function:
  ```r
  if (!data.table::is.data.table(tree_dt))
    cli::cli_abort("{.arg tree_dt} must be a {.cls data.table}, not {.cls {class(tree_dt)[1L]}}.")
  if (!"path" %in% names(tree_dt))
    cli::cli_abort("{.arg tree_dt} must contain a {.field path} column.")
  if (!is.character(tree_dt[["path"]]))
    cli::cli_abort("Column {.field path} must be character, not {.cls {class(tree_dt$path)[1L]}}.")
  ```

---

### P2 — IMPORTANT (should fix)

- **[P2.1]** [cg-testing] `tests/testthat/test-spi-inventory-cache.R` — No explicit unit tests for `.spi_cache_dir()`.
  **Why**: The function creates the cache directory and is critical infrastructure, but is only tested indirectly via `local_inventory_cache()` mocking. Explicit tests verify the contract independently.
  **Fix**: Add a `describe(".spi_cache_dir()", {...})` block testing: returns a character path, creates the directory if absent, returns same path on repeated calls.

- **[P2.2]** [cg-testing] `tests/testthat/test-spi-inventory-cache.R` — No explicit unit tests for `.spi_cache_path()`.
  **Why**: This constructs all cache filenames and is in the critical path; not verified to produce the expected `tree_{version}.rds` format.
  **Fix**: Add `describe(".spi_cache_path()", {...})` testing: filename ends with `tree_master.rds`, different versions produce different paths.

- **[P2.3]** [cg-testing] `tests/testthat/test-spi-inventory-cache.R` — Round-trip test only verifies shape, not data values.
  **Why**: Row count and column names are checked, but actual cell values (`path`, `category`, `pillar`, etc.) are not compared. A silent corruption in write/read would go undetected.
  **Fix**: Expand with `expect_equal(result$path, original$path)` etc. across all 6 columns.

- **[P2.4]** [cg-testing] `tests/testthat/test-spi-inventory-cache.R` — `.spi_write_cache()` return value not explicitly tested.
  **Why**: Documented as returning the enriched tree invisibly, but no test asserts this — a change to return `NULL` would not be caught.
  **Fix**: Add test asserting `result <- .spi_write_cache(raw, "master")` returns a 6-column `data.table`.

- **[P2.5]** [cg-documentation] `R/spi-inventory-cache.R` (`.spi_read_cache()` roxygen) — The `\itemize{}` list of NULL-return cases is in the wrong order.
  **Why**: Documentation lists TTL expiry as second, but the code checks it last (after schema validation). Mismatches between docs and code execution erode trust.
  **Fix**: Reorder items to match code: file missing → corrupted → unexpected structure → incompatible schema → older than 30 days.

- **[P2.6]** [cg-architecture] `R/spi-inventory-cache.R` (`.spi_crawl_tree()` stub, line ~23) — Stub lives in the wrong module.
  **Why**: `spi-inventory-cache.R` owns cache I/O. The stub is a GitHub API concern — the same responsibility as `.spi_github_get_json()` and `spi_versions()` in `spi-github.R`. When `github-tree-crawler` is implemented, this function will need to move anyway.
  **Fix**: Move `.spi_crawl_tree()` (stub, future implementation) to `R/spi-github.R`.

- **[P2.7]** [cg-architecture] `R/spi-inventory-cache.R` vs `R/spi-download.R` — Naming collision between `.spi_cache` (env, in-session) and `.spi_cache_dir()` / `.spi_cache_path()` / `.spi_write_cache()` / `.spi_read_cache()` (on-disk) helpers.
  **Why**: Both systems share the `.spi_cache` prefix but have different semantics and lifecycles. A maintainer reading either file must context-switch. The public API is already well-named (`spi_clear_cache` vs `spi_clear_inventory`); internal helpers should match.
  **Fix**: Rename on-disk helpers to `.spi_inv_cache_dir()`, `.spi_inv_cache_path()`, `.spi_inv_write_cache()`, `.spi_inv_read_cache()`.

- **[P2.8]** [cg-architecture] `R/spi-inventory-cache.R` (`.spi_enrich_tree()`) — Path-parsing logic belongs in `spi-filters.R`, not the cache module.
  **Why**: Pillar/dimension/category extraction from paths is the same concern as `filter_columns_by_pillar()` and `identify_id_columns()` already in `spi-filters.R`. Bundling it with cache I/O creates a dual-responsibility module.
  **Fix**: Move `.spi_enrich_tree()` to `R/spi-filters.R`. No interface changes needed.

- **[P2.9]** [cg-data-quality] `R/spi-inventory-cache.R` (`.spi_enrich_tree()`) — NA values in the `path` column are silently promoted to `category = "misc"`.
  **Why**: `startsWith(NA_character_, prefix)` returns `NA`, which acts like `FALSE` in logical assignment, silently giving NA paths the "misc" category. This masks a real crawl defect without warning.
  **Fix**: After `path <- dt[["path"]]`, add:
  ```r
  na_paths <- sum(is.na(path))
  if (na_paths > 0L)
    cli::cli_warn("{na_paths} NA value{?s} in {.field path} treated as {.val misc}.")
  ```

- **[P2.10]** [cg-data-quality] `R/spi-inventory-cache.R` (`.spi_read_cache()` TTL check) — `difftime()` is called outside the `tryCatch`, so a corrupt `timestamp` field (not POSIXct) throws an uncaught error.
  **Why**: Only the `readRDS()` call has error handling. A manually edited RDS or future refactor could produce a non-POSIXct timestamp, propagating a confusing error to the user.
  **Fix**: After the structure check, add inside the guard:
  ```r
  if (!inherits(cache_obj[["timestamp"]], "POSIXct")) {
    cli::cli_warn("Cached inventory for {.val {version}} has an invalid timestamp and will be deleted.")
    unlink(path)
    return(NULL)
  }
  ```

- **[P2.11]** [cg-data-quality] `R/spi-inventory-cache.R` (`.spi_read_cache()`) — The `tree` data.table is returned without schema validation.
  **Why**: The outer list-structure check confirms three named slots exist but says nothing about the contents of `tree`. A type mismatch or missing columns would propagate to all callers.
  **Fix**: Before returning, validate:
  ```r
  tree <- cache_obj[["tree"]]
  expected_cols <- c("path", "type", "size", "category", "pillar", "dimension")
  if (!data.table::is.data.table(tree) || !all(expected_cols %in% names(tree))) {
    cli::cli_warn("Cached inventory for {.val {version}} has an unexpected tree schema and will be deleted.")
    unlink(path)
    return(NULL)
  }
  return(tree)
  ```

- **[P2.12]** [cg-data-quality] `R/spi-inventory-cache.R` (`.spi_get_inventory()`) — No `version` argument validation, unlike both exported callers.
  **Why**: `spi_update_inventory()` and `spi_clear_inventory()` both guard `version`. The internal resolver passes it directly to `.spi_read_cache()` / `.spi_write_cache()`. Future consumers (`spi_get_raw()`) will call this function directly.
  **Fix**: Add at the top of `.spi_get_inventory()`:
  ```r
  if (!is.character(version) || length(version) != 1L || !nzchar(version))
    cli::cli_abort("{.arg version} must be a single non-empty character string.")
  ```

---

### P3 — MINOR (nice to have)

- **[P3.1]** [cg-code-quality] `tests/testthat/test-spi-inventory-cache.R:58` — Verbose column assertion. **Fix**: `expect_setequal(names(result), c("path", "type", "size", "category", "pillar", "dimension"))`.

- **[P3.2]** [cg-testing] `tests/testthat/test-spi-inventory-cache.R` — No edge case for multi-digit pillar-like folder names (e.g. `10_NewPillar`). **Fix**: Optional test covering folder names starting with `10+`.

- **[P3.3]** [cg-testing] `tests/testthat/test-spi-inventory-cache.R` — No test for permission errors in `.spi_cache_dir()`. **Fix**: Low priority (OS-dependent); document as known gap.

- **[P3.4]** [cg-documentation] `R/spi-inventory-cache.R:15-16` — `INVENTORY_CACHE_SCHEMA_VERSION` and `INVENTORY_CACHE_TTL_DAYS` lack inline comments. **Fix**: Add brief `# ...` comments explaining purpose.

- **[P3.5]** [cg-documentation] `R/spi-inventory-cache.R` — Exported functions missing `@family` tags. **Fix**: Add `@family spi-inventory-cache` to `spi_update_inventory()`, `spi_clear_inventory()`, and related internal functions.

- **[P3.6]** [cg-performance] `R/spi-inventory-cache.R` — Two sequential `dt[, col := val]` calls. **Fix**: `dt[, ':='(pillar = pil_vec, dimension = dim_vec)]`.

- **[P3.7]** [cg-performance] `R/spi-inventory-cache.R` — `data.table::copy()` doubles transient memory with no benefit since `.spi_enrich_tree()` is only called from `.spi_write_cache()`. **Fix**: Remove `copy()` and document in-place mutation (standard data.table idiom); or keep copy and note this is an explicit purity contract.

- **[P3.8]** [cg-performance] `R/spi-inventory-cache.R` — `saveRDS()` uses default gzip compression. For a small cache file read on every inventory call, `compress = FALSE` gives 2–4× faster reads with negligible size penalty. **Fix**: `saveRDS(cache_obj, file = .spi_cache_path(version), compress = FALSE)`.

- **[P3.9]** [cg-performance] `R/spi-inventory-cache.R` — Two independent `grep()` passes where `dim_hits` is a subset of `pil_hits`. **Fix**: `pil_hits <- grep("^[0-9]+", subdir); dim_hits <- pil_hits[grepl("^[0-9]+\\.[0-9]+", subdir[pil_hits])]`.

- **[P3.10]** [cg-architecture] `R/spi-inventory-cache.R:15-16` — `INVENTORY_CACHE_*` constants break the `SPI_` prefix convention (`SPI_GITHUB_BASE`, `SPI_FILE_PATHS`, `SPI_REQUIRED_COLS`). **Fix**: Rename to `SPI_INVENTORY_CACHE_SCHEMA_VERSION` and `SPI_INVENTORY_CACHE_TTL_DAYS`.

- **[P3.11]** [cg-architecture] `R/spi-inventory-cache.R` — Two section headers labeled "Step 2". **Fix**: Renumber sections consecutively: Step 1 (enrichment), Step 2 (dir helpers), Step 3 (read/write), Step 4 (resolver), Step 5 (exports).

- **[P3.12]** [cg-architecture] `R/spi-inventory-cache.R` (`.spi_get_inventory()`) — Cache-miss path uses implicit last-value return from `.spi_write_cache()`. **Fix**: `result <- .spi_write_cache(tree_dt, version); invisible(result)`.

- **[P3.13]** [cg-architecture] `R/spi-inventory-cache.R` (`spi_clear_inventory()`) — Calling `.spi_cache_dir()` creates the directory as a side effect during a deletion operation. **Fix**: Use `tools::R_user_dir("spiR", "cache")` directly to resolve the path in `spi_clear_inventory()`, guarding with `if (dir.exists(...))`.

- **[P3.14]** [cg-data-quality] `R/spi-inventory-cache.R` (`.spi_write_cache()`) — A 0-row tree from the crawler is cached silently with a fresh 30-day TTL, masking crawler failures. **Fix**: Add `if (nrow(tree_dt) == 0L) cli::cli_warn("Crawler returned an empty tree for {.val {version}}; caching anyway.")`.

---

### ✅ Passed

- **cg-version-control**: No issues found — conventional commit format correct, no secrets, NAMESPACE correctly committed, `.gitignore` and `.Rbuildignore` clean.
- **cg-reproducibility**: No issues found — portable `tools::R_user_dir()`, named TTL/schema constants, deterministic regex operations, `Sys.time()` use appropriately documented.
- **cg-code-quality**: No P1/P2 issues — style, naming, error handling, data.table patterns all correct.
