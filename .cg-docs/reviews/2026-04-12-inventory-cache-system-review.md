---
plan: .cg-docs/plans/2026-04-11-inventory-cache-system.md
findings:
  P1.1: open
  P1.2: open
  P2.1: open
  P2.2: open
  P2.3: open
  P2.4: open
  P2.5: open
  P2.6: open
  P2.7: open
  P2.8: open
  P2.9: open
  P3.1: open
  P3.2: open
  P3.3: open
  P3.4: open
  P3.5: open
  P3.6: open
  P3.7: open
  P3.8: open
  P3.9: open
  P3.10: open
---

## Review Report

**Review depth**: standard
**Files reviewed**: 4 (`R/spi-inventory-cache.R`, `R/spi-filters.R`, `R/spi-github.R`, `tests/testthat/test-spi-inventory-cache.R`)
**Findings**: 0 P0, 2 P1, 9 P2, 10 P3

---

### P1 — CRITICAL (must fix before merge)

- **[P1.1]** [cg-architecture] `R/spi-inventory-cache.R` (`.spi_get_inventory()`) — Bare `error =` handler in the crawler fallback swallows all `.spi_crawl_tree()` failures and relabels them as a network connectivity error.
  **Why**: The current guard is `tryCatch(.spi_crawl_tree(version), error = function(e) cli::cli_abort("No cached inventory found and the GitHub API could not be reached."))`. Since `.spi_crawl_tree()` is a stub that always calls `cli::cli_abort()`, the user today sees "Connect to the internet and try again" — which is actively wrong advice. After the real crawler lands, the same catch will misdiagnose rate-limiting, auth failures, and parse errors as connectivity problems, destroying actionable guidance.
  **Fix**: Give `.spi_crawl_tree()` a distinct condition class (`"spi_not_implemented"`) and catch only network-class conditions. At minimum, chain the original error via `parent = e` so the true cause surfaces.

- **[P1.2]** [cg-data-quality] `R/spi-inventory-cache.R` (`.spi_inv_write_cache()`) — Empty tree is warned about but cached anyway, causing 30 days of silent empty-inventory.
  **Why**: `nrow(tree_dt) == 0L` triggers a `cli_warn()` then proceeds to write a 0-row data.table to disk. On next read, `.spi_inv_read_cache()` returns this as **valid** (correct schema, fresh timestamp, all 6 columns present on a 0-row table). Every downstream call returns nothing for 30 days with no diagnostic. An empty-tree response from the crawler is almost certainly a network/API error.
  **Fix**: Replace `cli::cli_warn(...)` with `cli::cli_abort(...)` and do not write the cache.

---

### P2 — IMPORTANT (should fix)

- **[P2.1]** [cg-testing] `tests/testthat/test-spi-inventory-cache.R` (`.spi_enrich_tree()` block) — No test for the third input-validation guard: non-character `path` column.
  **Why**: The implementation has `if (!is.character(tree_dt[["path"]])) cli::cli_abort(...)` but no test exercises this path. The other two guards (non-data.table, missing path column) are tested.
  **Fix**: Add `it("errors clearly when path column is not character", { expect_error(.spi_enrich_tree(data.table(path = 1:3, type = "blob", size = 100L)), "must be character") })`.

- **[P2.2]** [cg-testing] `tests/testthat/test-spi-inventory-cache.R` (`spi_clear_inventory()` block) — Four distinct `cli_inform()` messages from `spi_clear_inventory()` are never checked.
  **Why**: All clear tests use `expect_no_error()` or `expect_false(file.exists(...))`. If message strings break or regress, no test fails.
  **Fix**: Add `expect_message()` assertions for each of the four scenarios: version cleared, version not found, cache already empty, all-files count.

- **[P2.3]** [cg-documentation] `R/spi-inventory-cache.R` (`.spi_inv_cache_path()`) — Path traversal guard not mentioned in roxygen2 description.
  **Why**: The function silently rejects version strings with path separators — a security behavior — but `@description` only says "Build the absolute path to a version's inventory cache file." Maintainers and auditors cannot find the guard without reading the body.
  **Fix**: Add `@description` text: `"Constructs the cache file path. Validates that `version` does not contain path separators, protecting against path traversal."`.

- **[P2.4]** [cg-reproducibility] `R/spi-inventory-cache.R` — TTL-based cache expiry creates time-dependent behavior without documentation.
  **Why**: Results returned by `.spi_get_inventory()` depend on whether a 30-day clock has elapsed. An analysis run on day 29 returns cached data; the same script run on day 31 auto-re-crawls and may return different data. No documentation warns that reproducible workflows should pin inventory via `spi_update_inventory()`.
  **Fix**: Add a note to `spi_update_inventory()` `@description` and README: *"For reproducible workflows, call `spi_update_inventory()` explicitly before distributing analysis code rather than relying on automatic 30-day TTL expiry."*

- **[P2.5]** [cg-architecture] `R/spi-filters.R` — `.spi_enrich_tree()` has low cohesion with the rest of `spi-filters.R`.
  **Why**: Every other function in `spi-filters.R` operates on SPI output CSV data.tables. `.spi_enrich_tree()` operates on a GitHub file tree. Its only consumer is `spi-inventory-cache.R`. Moving it there makes `spi-inventory-cache.R` fully self-contained, eliminates a cross-module dependency, and clarifies each file's responsibility.
  **Fix**: Move `.spi_enrich_tree()` into `R/spi-inventory-cache.R`.

- **[P2.6]** [cg-architecture] `R/spi-inventory-cache.R`, `R/spi-data.R`, `R/spi-download.R` — Version argument validation is duplicated across 5 functions.
  **Why**: The guard `if (!is.character(version) || length(version) != 1L || !nzchar(version)) cli::cli_abort(...)` appears verbatim (with message wording drift) in `.spi_get_inventory()`, `spi_update_inventory()`, `spi_clear_inventory()`, `spi_get()`, and `spi_download()`. Future rule changes must be applied in 5 places.
  **Fix**: Extract `.spi_validate_version(version)` as a single internal helper.

- **[P2.7]** [cg-data-quality] `R/spi-filters.R` (`.spi_enrich_tree()`) — `type` and `size` input columns not validated.
  **Why**: If `.spi_crawl_tree()` returns a data.table missing `type` or `size`, the function enriches silently producing a 5-column result. `.spi_inv_write_cache()` writes it; `.spi_inv_read_cache()` then warns, deletes, and re-triggers a crawl that returns the same bad tree — creating a write-delete-recrawl loop.
  **Fix**: Add column-presence checks for `type` and `size` after the existing `path` checks.

- **[P2.8]** [cg-data-quality] `R/spi-inventory-cache.R` (`.spi_inv_read_cache()`, tree schema block) — `size` column storage type is never validated.
  **Why**: Documented contract states `size` is integer. A JSON-parser edge case could produce `size` as character; this passes all current checks and reaches arithmetic code with silent NA production.
  **Fix**: `if (!is.integer(tree[["size"]]) && !is.numeric(tree[["size"]])) { cli::cli_warn(...); unlink(path); return(NULL) }`.

- **[P2.9]** [cg-data-quality] `R/spi-inventory-cache.R` (`.spi_inv_read_cache()`, tree schema block) — `type` column values not validated against `"blob"`/`"tree"` contract.
  **Why**: Column presence is checked but not values. An API change or corrupt cache could introduce arbitrary strings that would be silently returned to callers.
  **Fix**: `if (!all(tree[["type"]] %in% c("blob", "tree") | is.na(tree[["type"]]))) { cli::cli_warn(...); unlink(path); return(NULL) }`.

---

### P3 — MINOR (nice to have)

- **[P3.1]** [cg-testing] `tests/testthat/test-spi-inventory-cache.R` — No test for cached tree with correctly-named but wrong-type columns.
  **Why**: `.spi_inv_read_cache()` validates column presence but not types. A test now would also serve as a regression guard if P2.8 is implemented.
  **Fix**: Add a test building a cache with `path = 1:3L` (integer) and asserting warn+NULL+file-deleted.

- **[P3.2]** [cg-testing] `tests/testthat/test-spi-inventory-cache.R` — Error assertions match on string only, not condition class.
  **Why**: `expect_error(..., "No cached inventory found")` passes for any error containing that string, not just `cli_abort`. Using `class = "cli_abort"` makes assertions precise.
  **Fix**: Add `class = "cli_abort"` to `expect_error()` calls in the network-failure tests.

- **[P3.3]** [cg-documentation] `R/spi-inventory-cache.R` — Internal helpers `.spi_inv_cache_dir()` and `.spi_inv_cache_path()` have minimal documentation compared to `.spi_github_get_json()`.
  **Why**: `.spi_github_get_json()` explains *why* it exists (enabling test mocking). The cache helpers are similarly mockable but only describe *what*.
  **Fix**: Add a sentence explaining mockability: `"Thin wrapper around tools::R_user_dir() so tests can redirect the cache via local_mocked_bindings(.spi_inv_cache_dir = ...)."`.

- **[P3.4]** [cg-documentation] `R/spi-github.R` (`spi_versions()`) — Pagination constraint not mentioned in `@description`.
  **Why**: The function warns at runtime when exactly 100 branches are returned, but user documentation says nothing about this.
  **Fix**: Add to `@description`: `"If the repository has more than 100 branches, the list may be incomplete due to GitHub API pagination limits; a warning is issued in this case."`.

- **[P3.5]** [cg-performance] `R/spi-filters.R` (`.spi_enrich_tree()`, `dim_hits` block) — `subdir[dim_hits]` materialised twice in the `regmatches()` call.
  **Why**: `regmatches(subdir[dim_hits], regexpr("...", subdir[dim_hits]))` allocates the same sub-vector twice. Inconsistent with the two-pass grep optimisation.
  **Fix**: `sub_dim <- subdir[dim_hits]; dim_vec[dim_hits] <- regmatches(sub_dim, regexpr(..., sub_dim))`. Apply same to the `pil_hits` block.

- **[P3.6]** [cg-performance] `R/spi-filters.R` (`filter_columns_by_pattern()`) — `names(dt)` evaluated three times across `identify_id_columns()` + `filter_columns_by_pattern()`.
  **Why**: Three materializations of the same name vector across the call chain.
  **Fix**: `cols <- names(dt); is_id <- !grepl("^SPI\\.D[0-9]|^RAW\\.D[0-9]", cols); is_ind <- grepl(pattern, cols); dt[, cols[is_id | is_ind], with = FALSE]` — one `names()`, two `grepl` passes.

- **[P3.7]** [cg-architecture] `R/spi-inventory-cache.R` — `spi_update_inventory()` is exported and documented as user-facing, but always aborts with an internal stub error.
  **Why**: Users who install the dev package before `github-tree-crawler` merges see internal vocabulary (`"github-tree-crawler"`) in an error from a documented public function.
  **Fix**: Remove `@export` until the crawler milestone lands (fully reversible), or add `@section Development status:` noting it is non-operational until then.

- **[P3.8]** [cg-architecture] `R/spi-inventory-cache.R` (`.spi_get_inventory()`) — Cache-hit returns visibly; cache-miss returns invisibly. Inconsistent return visibility.
  **Why**: `return(cached)` vs `invisible(result)` — different contract for the same function depending on the code path.
  **Fix**: Change cache-hit to `invisible(cached)`.

- **[P3.9]** [cg-data-quality] `R/spi-inventory-cache.R` (`.spi_inv_write_cache()`) — `nrow(tree_dt)` called before type validation produces opaque base R error for list input.
  **Why**: `nrow(list(...))` returns `NULL`; `if (NULL == 0L)` throws "argument is of length zero" before `.spi_enrich_tree()` can emit its clean validation message.
  **Fix**: Add `if (!data.table::is.data.table(tree_dt)) cli::cli_abort(...)` as the very first line of `.spi_inv_write_cache()`, before the `nrow()` check.

- **[P3.10]** [cg-data-quality] `R/spi-inventory-cache.R` (`.spi_inv_read_cache()`, TTL check) — Negative `age_days` from clock skew makes the cache immortal.
  **Why**: `if (age_days > SPI_INVENTORY_CACHE_TTL_DAYS)` never fires when `age_days < 0` (NTP step backward after cache was written). The cache is served forever until the clock catches up.
  **Fix**: `if (age_days < 0 || age_days > SPI_INVENTORY_CACHE_TTL_DAYS) return(NULL)`.

---

### ✅ Passed

- **cg-code-quality**: No issues found — style, naming (`<-`, `UPPER_SNAKE_CASE` constants, `.spi_*` internal prefix), error handling, and data.table idioms all consistent.
- **cg-version-control**: No issues found — conventional commit format, no secrets or data files, renv.lock correctly committed, man/ Rd files appropriate.
