---
plan: .cg-docs/plans/2026-04-10-milestone-1-output-data-mvp.md
findings:
  P1.1: open
  P1.2: open
  P1.3: open
  P1.4: open
  P1.5: open
  P1.6: open
  P1.7: open
  P1.8: open
  P2.1: open
  P2.2: open
  P2.3: open
  P2.4: open
  P2.5: open
  P2.6: open
  P2.7: open
  P2.8: open
  P2.9: open
  P2.10: open
  P2.11: open
  P2.12: open
  P2.13: open
  P2.14: open
  P2.15: open
  P2.16: open
  P3.1: open
  P3.2: open
  P3.3: open
  P3.4: open
  P3.5: open
  P3.6: open
  P3.7: open
  P3.8: open
---

## Review Report

**Review depth**: standard
**Files reviewed**: 15 (R/spi-download.R, R/spi-filters.R, R/spi-data.R, R/spi-wrappers.R, R/spiR-package.R, DESCRIPTION, NAMESPACE, .Rbuildignore, tests/testthat.R, tests/testthat/test-spi-download.R, tests/testthat/test-spi-filters.R, tests/testthat/test-spi-data.R, tests/testthat/test-spi-wrappers.R, tests/testthat/test-spi-versions.R, tests/testthat/test-integration.R)
**Findings**: 8 P1, 16 P2, 8 P3

---

### P1 — CRITICAL (must fix before merge)

- **[P1.1]** [cg-data-quality] `R/spi-data.R` — `year` type mismatch silently returns 0 rows
  **Why**: `year` is never type-validated. A user calling `spi_get("data", year = "2024")` gets an empty `data.table` with no error because `integer %in% character` always returns `FALSE` in R. Impossible to distinguish from "no data for that year."
  **Fix**: Add validation before the year filter block:
  ```r
  if (!is.null(year)) {
    if (!is.numeric(year) && !is.integer(year))
      rlang::abort(paste0("`year` must be a numeric or integer vector, not ", class(year)[1L], "."))
    if (anyNA(year))
      rlang::abort("`year` must not contain NA values.")
  }
  ```

- **[P1.2]** [cg-data-quality] `R/spi-data.R` — `country = NA` / `region = NA` silently returns 0 rows
  **Why**: Neither `country` nor `region` is type-checked or NA-checked. `dt[["iso3c"]] %in% NA` is all-`FALSE`, so the result is an empty `data.table` with no diagnostic.
  **Fix**:
  ```r
  if (!is.null(country)) {
    if (!is.character(country) || anyNA(country))
      rlang::abort("`country` must be a character vector with no NA values.")
  }
  if (!is.null(region)) {
    if (!is.character(region) || anyNA(region))
      rlang::abort("`region` must be a character vector with no NA values.")
  }
  ```

- **[P1.3]** [cg-data-quality] `R/spi-download.R` — No schema validation after `fread()`
  **Why**: If a wrong or WIP branch has a different CSV schema, `dt[["iso3c"]]` returns `NULL` and `NULL %in% country` returns `logical(0)`, causing `dt[logical(0)]` to silently return 0 rows instead of an actionable error.
  **Fix**: Add a schema guard immediately after download in `spi_get()`:
  ```r
  required_cols <- c("iso3c", "date")
  missing_cols <- setdiff(required_cols, names(dt))
  if (length(missing_cols) > 0L) {
    rlang::abort(paste0(
      "Downloaded file is missing expected columns: ",
      paste(missing_cols, collapse = ", "), ".\n",
      "Check that version = \"", version, "\" points to a valid SPI release."
    ))
  }
  ```

- **[P1.4]** [cg-reproducibility] `renv.lock` — Incomplete lockfile missing `rlang` and `withr`
  **Why**: `DESCRIPTION` declares `rlang` in `Imports` and `withr` is used by testthat for `local_mocked_bindings()`, but neither appears in `renv.lock`. Collaborators running `renv::restore()` won't get these packages.
  **Fix**: Run `renv::snapshot()` to regenerate the lockfile with all transitive dependencies.

- **[P1.5]** [cg-documentation] `README.md` — README is essentially empty (one line)
  **Why**: `README.md` contains only "This is an R package to access the SPI data." It is the primary user-facing entry point. Missing: installation, quick-start examples, data type overview, links to SPI repo.
  **Fix**: Expand README to include: installation via `pak::pkg_install("WB-DECIS/spiR")`; a quick-start `spi_data()` / `spi_get()` example; description of the three data types (data, index, aggregates); link to World Bank SPI GitHub repo.

- **[P1.6]** [cg-testing] `tests/testthat/test-spi-download.R` — Non-zero `download.file` exit status untested
  **Why**: The `if (result != 0L)` error path in `spi_download()` is never exercised by tests. A test that mocks `download.file` returning `1L` is needed to verify the error is raised and informative.
  **Fix**:
  ```r
  test_that("spi_download() errors when download.file returns non-zero status", {
    mock_fail <- function(url, destfile, quiet, mode) invisible(1L)
    local_mocked_bindings(download.file = mock_fail, .package = "utils",
      expect_error(spi_download("03_output_data/SPI_data.csv"), "non-zero")
    )
  })
  ```

- **[P1.7]** [cg-testing] `tests/testthat/test-spi-data.R` — `type = "index"` never unit tested
  **Why**: All unit tests use `type = "data"` or `type = "aggregates"`. The `"index"` type path is only exercised by integration tests (network-dependent). A unit test with the mocked index data.table is needed.
  **Fix**: Add two tests using `mock_spi_download` → `make_mock_index_dt()`:
  ```r
  test_that("spi_get('index') returns data.table", { ... })
  test_that("spi_get('index') includes SPI.INDEX column", { ... })
  ```

- **[P1.8]** [cg-testing] `tests/testthat/test-spi-versions.R` — "master always present" guarantee not tested
  **Why**: The `spi_versions()` docs promise `"master"` is always in the result, but the code extracts names from whatever the API returns — if "master" is absent from the API response, the guarantee silently breaks.
  **Fix**: Either add enforcement in `spi_versions()` (union the result with `"master"`) and add a test that confirms the guarantee holds when the API omits "master", or remove the guarantee from the docs.

---

### P2 — IMPORTANT (should fix)

- **[P2.1]** [cg-data-quality] `R/spi-data.R` — `dimension = NA_character_` produces a cryptic base R error
  **Why**: `grepl()` propagates `NA`, so `!grepl(pattern, NA_character_)` returns `NA`, and `if (NA)` throws `"missing value where TRUE/FALSE needed"` — not the package's clear validation message.
  **Fix**: Add `is.na(dimension)` to the validation guard (as already done for `pillar`).

- **[P2.2]** [cg-data-quality] `R/spi-download.R` — No warning when downloaded file has 0 rows
  **Why**: `fread()` on an empty CSV succeeds silently. Callers can't distinguish "valid empty result after filtering" from "source file was empty on this branch."
  **Fix**: Add `if (nrow(dt) == 0L) rlang::warn(...)` with URL and version in `spi_download()`.

- **[P2.3]** [cg-architecture + cg-performance] `R/spi-data.R` — `spi_versions()` uses `readLines()` for HTTP (two HTTP mechanisms, no User-Agent, manual JSON parsing)
  **Why**: `spi_download()` uses `utils::download.file()`; `spi_versions()` uses `readLines()`. These are two uncoordinated HTTP mechanisms. `readLines()` sends no User-Agent header (GitHub API may return 403 under automation), and JSON is parsed with brittle regex instead of proper parsing. The team standard is `httr2`.
  **Fix**: Add `httr2` to `Imports`. Refactor `spi_versions()` to use `httr2::request() |> httr2::req_headers(...) |> httr2::req_perform()` and parse with `httr2::resp_body_json()`: `vapply(parsed, `[[`, character(1L), "name")`. Consider also migrating `spi_download()` to `httr2`.

- **[P2.4]** [cg-architecture] `R/spi-data.R`, `R/spi-download.R` — `rlang::abort(paste0(...))` instead of `cli::cli_abort()`
  **Why**: The team standard per `cg-skill-r-technical` is `cli::cli_abort()` with markup. This enables user-friendly formatting, proper call-site attribution, and future expansion with `"i"` advice bullets.
  **Fix**: Add `cli (>= 3.0.0)` to `Imports`. Replace `rlang::abort(paste0(...))` with `cli::cli_abort(...)`. If `rlang` becomes unused, remove it from `Imports`.

- **[P2.5]** [cg-performance] `R/spi-download.R` — No in-session caching; full network download on every call
  **Why**: `SPI_data.csv` (~2–5 MB, 200 countries × 10+ years × 100+ columns) is downloaded fresh on every `spi_data()` call. A typical exploratory session re-downloads the same file 3–5 times, paying 1–5 s of network latency each time.
  **Fix**: Add a package-level environment cache keyed on `(file_path, version)`:
  ```r
  .spi_cache <- new.env(parent = emptyenv())
  ```
  Check/populate on each `spi_download()` call. Expose `spi_clear_cache()` for users who want to force a refresh.

- **[P2.6]** [cg-code-quality] `R/spi-data.R:85-88` — `version` error message doesn't show what was passed
  **Why**: `spi_get()`'s `version` validation error says "`version` must be a single non-empty character string." but doesn't show what was actually passed, unlike `spi_download()`'s error which includes `class(version)[1L]`.
  **Fix**: Add `class(version)[1L]` context: `paste0("..., not ", class(version)[1L], ".")`.

- **[P2.7]** [cg-code-quality] `R/spi-filters.R:58-85` — DRY violation between `filter_columns_by_pillar()` and `filter_columns_by_dimension()`
  **Why**: Both functions share identical logic (get id columns, build pattern, grep column names, subset). They differ only in how the pattern is built. Duplicated code increases maintenance burden.
  **Fix**: Extract a shared `filter_columns_by_pattern(dt, pattern)` private helper and call it from both functions.

- **[P2.8]** [cg-code-quality] `R/spi-download.R:52`, `R/spi-data.R:180`, `R/spi-data.R:220` — Missing explicit `return()` at end of non-trivial functions
  **Why**: Per `cg-skill-r-shared`, non-trivial functions with multiple code paths should have explicit `return()` on the last statement for clarity.
  **Fix**: Add `return(dt)` / `return(branch_names)` to the final expression of `spi_download()`, `spi_get()`, and `spi_versions()`.

- **[P2.9]** [cg-testing] `tests/testthat/test-spi-download.R` — `fread()` parse failure path untested
  **Why**: No test exercises the tryCatch in `spi_download()` when `fread()` throws (e.g., corrupt file). The error-wrapping code could be silently broken.
  **Fix**: Add a test that mocks `data.table::fread` to throw, and asserts the wrapped error message is informative.

- **[P2.10]** [cg-testing] `tests/testthat/test-spi-wrappers.R` — Wrappers test delegation but not behavior
  **Why**: Wrapper tests assert that `spi_download` is called with the right path, but never assert that filtering arguments actually produce correct output. A broken filter could pass these tests.
  **Fix**: Add at least one behavioral assertion per wrapper (e.g., `spi_data(country = "NOR")` returns 1 row, `spi_aggregates()` returns only aggregate codes).

- **[P2.11]** [cg-testing] `tests/testthat/test-spi-data.R` — Year as vector and empty-vector edge cases untested
  **Why**: Year filter tests use only single-value integer (`year = 2024L`). No test for `year = c(2023L, 2024L)` (multi-year) or `country = character(0)` / `year = integer(0)` (empty vectors that should return 0 rows).
  **Fix**: Add tests for multi-year and empty-vector inputs.

- **[P2.12]** [cg-testing] `tests/testthat/test-spi-filters.R` — Pillars 4 & 5 and no-indicator-column edge cases untested
  **Why**: `filter_columns_by_pillar()` is tested for pillars 1–3 only. No test for a `data.table` with zero indicator columns (returns only ID cols).
  **Fix**: Add tests for pillars 4 and 5, and an edge-case test with a metadata-only `data.table`.

- **[P2.13]** [cg-documentation] `DESCRIPTION` — Missing `URL` and `BugReports` fields
  **Why**: Standard for R packages on GitHub; enables `?spiR` to link to the repo and helps users report issues.
  **Fix**: Add `URL: https://github.com/WB-DECIS/spiR` and `BugReports: https://github.com/WB-DECIS/spiR/issues` to `DESCRIPTION`.

- **[P2.14]** [cg-version-control] — Missing `NEWS.md`
  **Why**: `NEWS.md` tracks user-visible changes across releases. Projects without it lose change history.
  **Fix**: Create `NEWS.md` with a stub entry for `# spiR 0.0.0.9000` marking Milestone 1 completion.

- **[P2.15]** [cg-version-control] — No GitHub Actions CI workflow
  **Why**: No `.github/workflows/` directory means R CMD check never runs automatically on push/PR. Regressions will only be caught locally.
  **Fix**: Add `.github/workflows/R-CMD-check.yaml` using the standard `r-lib/actions/check-r-package@v2` action.

- **[P2.16]** [cg-reproducibility] `DESCRIPTION` — `withr` in `Suggests` without version constraint
  **Why**: Other suggests have `>= X.X.X` bounds; `withr` does not. `local_mocked_bindings()` requires withr ≥ 2.5.0.
  **Fix**: Change to `withr (>= 2.5.0)` in `Suggests`.

---

### P3 — MINOR (nice to have)

- **[P3.1]** [cg-architecture] `R/spi-data.R` — `spi_versions()` should move to `R/spi-github.R`
  **Why**: `spi_get()` orchestrates data retrieval; `spi_versions()` is a GitHub API discovery function. Grouping them blurs the file's responsibility as Milestone 2 adds more discovery functions.
  **Fix**: Move `spi_versions()` to a new `R/spi-github.R` that becomes the home for all GitHub-API-facing helpers.

- **[P3.2]** [cg-architecture] `R/spi-data.R` — `per_page=100` pagination not guarded
  **Why**: If SPI ever exceeds 100 branches, `spi_versions()` silently returns a truncated list.
  **Fix**: After migrating to `httr2`, check the `Link: rel="next"` response header or add `if (length(result) == 100L) cli::cli_warn("Result may be incomplete...")`.

- **[P3.3]** [cg-performance] `R/spi-data.R:141,145,160,164` — Intermediate `keep` vector; use inline `dt[col %in% x]`
  **Why**: The `keep <- ...; dt <- dt[keep]` pattern materialises an extra logical vector. The idiomatic data.table form is `dt <- dt[iso3c %in% country]` (inlined — data.table's `[i]` resolves column names directly when called from within a package that imports data.table).
  **Fix**: Replace the four `keep <-` / `dt[keep]` pairs with inline versions. (Note: this was valid before the `@importFrom data.table` fix; now that data.table is imported it should work inline too.)

- **[P3.4]** [cg-performance] `R/spi-filters.R:60,77` — `names(dt)` + `grepl()` called 3× per column-filter invocation
  **Why**: `identify_id_columns()` calls `names()` + `grepl`, then both `filter_columns_by_*` functions call `names()` + `grepl` again. That's three `names()` calls and two `grepl` passes on the same ~100-element vector.
  **Fix**: Capture `nms <- names(dt)` once and pass it through, or inline the logic as described in the DRY fix (P2.7).

- **[P3.5]** [cg-version-control] — All Milestone 1 work committed directly to `main` (no feature branch)
  **Why**: Commits directly to `main` make it hard to review changes and roll back if needed. Future milestones should use feature branches (`feat/milestone-2-inventory-raw-data`).
  **Fix**: Document the branching convention in `CONTRIBUTING.md` or README; use feature branches from Milestone 2 onward.

- **[P3.6]** [cg-reproducibility] `R/spi-data.R` — `spi_versions()` result not sorted
  **Why**: GitHub API doesn't guarantee branch order. Repeated calls may return branches in different order, making scripted comparisons fragile.
  **Fix**: Call `sort()` on the extracted branch names before returning.

- **[P3.7]** [cg-documentation] `R/spi-data.R` — `spi_versions()` missing `@seealso` link to `spi_get()`
  **Why**: The relationship between `spi_versions()` output and `spi_get(version = ...)` is not surfaced in the help page.
  **Fix**: Add `@seealso [spi_get()]` to the `spi_versions()` roxygen block.

- **[P3.8]** [cg-architecture] `R/spiR-package.R` — Some `@importFrom` declarations preemptive
  **Why**: `as.data.table`, `:=`, `.`, `.SD` and `globalVariables(c(".", ".SD"))` are declared but unused in the current codebase. This is forward-looking scaffolding for Milestone 2.
  **Fix**: Leave as-is if Milestone 2 is imminent; trim to just `@importFrom data.table fread` if not, to avoid stale declarations.

---

### ✅ Passed

- **cg-code-quality**: `<-` assignment, `snake_case`, `TRUE`/`FALSE`, no `T`/`F`, no commented-out code, no bare `cat()` or `print()` in production code, no magic numbers, roxygen2 present on all functions ✓
- **cg-architecture**: Layer separation (download / filter / orchestration / wrappers), single-responsibility files, correct export surface (5 public, 6 internal), no circular dependencies, clean NAMESPACE ✓
- **cg-reproducibility**: No hardcoded absolute paths, all filtering is deterministic, `skip_if_offline()` guards in integration tests, `mode = "wb"` for binary files, platform-neutral ✓
- **cg-data-quality**: `match.arg()` used for `type`, `pillar` validation correct (range, type, NA), filter helpers NULL-safe, `is_aggregate_code()` handles NA correctly ✓
- **cg-version-control**: No credentials or secrets, `.gitignore` comprehensive, `renv.lock` committed (contents incomplete — see P1.4), `0.0.0.9000` version correct for development ✓
- **cg-testing**: testthat 3rd edition with `local_mocked_bindings()`, integration tests properly guarded, mock data realistic, no test-coupling issues ✓
