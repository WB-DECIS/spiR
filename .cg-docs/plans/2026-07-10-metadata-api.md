---
date: 2026-07-10
title: "SPI Metadata API"
status: active
scope: "Standard"
phases: 2
brainstorm: null
language: "R"
estimated-effort: "medium"
deviation-policy: "ask"
tags: [api, metadata, pillars, dimensions, indicators, wrappers]
---

# Plan: SPI Metadata API

## Objective
Add a `metadata()` function and two wrappers — `metadata_pillars()` and
`metadata_dimensions()` — that let users explore the SPI indicator hierarchy
(pillars → dimensions → indicators) directly from the official metadata file,
before or alongside retrieving actual SPI data.

## Context
Existing wrappers (`spi_data()`, `spi_index()`, `spi_aggregates()`,
`spi_indicator()`, `country_info()`) all operate on output data. There is no
function that exposes the structural catalog of pillars, dimensions, and
indicators with their names, descriptions, IDs, scoring rules, and
abbreviations. The upstream file `01_raw_data/metadata/SPI_full_metadata.csv`
in the worldbank/SPI repository (added in commit 2b474a5) is the authoritative
source for this information. `metadata()` reads it via the existing
`spi_download()` engine and returns a stable, hierarchically-filtered list.
`metadata_pillars()` and `metadata_dimensions()` are thin wrappers for the
most frequent use cases.

## Requirements
| ID | Requirement | Source |
|----|-------------|--------|
| R1 | Export `metadata()` as the principal metadata access function. | User request |
| R2 | Export `metadata_pillars()` as a wrapper returning only pillar rows. | User request |
| R3 | Export `metadata_dimensions()` as a wrapper returning only dimension rows. | User request |
| R4 | Read `01_raw_data/metadata/SPI_full_metadata.csv` from worldbank/SPI via `spi_download()`. | Design decision |
| R5 | Accept `pillar`, `dimension`, and `indicator` as optional string arguments. | Design decision |
| R6 | Validate that all filter arguments are strings; abort with `cli::cli_abort()` if not. | Design decision |
| R7 | Validate hierarchical consistency: if both `pillar` and `dimension` are supplied, the dimension's implied pillar must match; abort if not. | Design decision |
| R8 | Return a named list with three `data.table` elements: `pillars`, `dimensions`, `indicators`. | Design decision |
| R9 | When a valid filter finds no match, return empty tables with `cli::cli_warn()`. | Package pattern |
| R10 | Fail loudly with `cli::cli_abort()` if required metadata columns are missing from the CSV. | Project rule |
| R11 | Add unit tests covering all filter combinations, type errors, hierarchy errors, and missing-column errors. | Plan quality |
| R12 | Keep implementation in `data.table` style with no new dependencies. | Project constraints |

## Phase 1: Core Implementation

### 1. Add internal metadata reader in `R/spi-data.R`
- **Requirements**: R4, R10, R12
- **Files**: `R/spi-data.R`
- **Details**:
  - Add constant:
    `SPI_METADATA_PATH <- "01_raw_data/metadata/SPI_full_metadata.csv"`.
  - Add internal function `.spi_read_metadata(version = "master")` that calls
    `spi_download(SPI_METADATA_PATH, version = version)`.
  - Validate that all required columns are present:
    `pillar`, `pillar_name`, `pillar_description`, `pillar_id`,
    `dimension`, `dimension_name`, `dimension_description`, `dimension_id`,
    `indicator`, `indicator_name`, `indicator_description`, `indicator_id`,
    `indicator_scoring`, `indicator_abv`.
  - If any column is missing, call `cli::cli_abort()` listing the missing
    columns and the `version` used.
  - Normalize `pillar` column to character for consistent filter matching.
  - Return the raw `data.table`; callers handle filtering.
- **Test Scenarios**: valid CSV, missing required column, empty file.
- **Tests**: `tests/testthat/test-spi-metadata.R`
- **Acceptance criteria**: `.spi_read_metadata()` returns a validated
  `data.table` or aborts with an informative message.

### 2. Implement `metadata()` in `R/spi-wrappers.R`
- **Requirements**: R1, R5, R6, R7, R8, R9, R12
- **Files**: `R/spi-wrappers.R`
- **Details**:
  - Function signature:
    `metadata <- function(pillar = NULL, dimension = NULL, indicator = NULL, version = "master")`.
  - Input validation (all before downloading data):
    - If `pillar` is not `NULL`, assert it is a single string in `{"1","2","3","4","5"}`;
      otherwise `cli::cli_abort()` with accepted values.
    - If `dimension` is not `NULL`, assert it is a single string matching
      `"^[0-9]+\\.[0-9]+$"`; otherwise `cli::cli_abort()` with format example.
    - If `indicator` is not `NULL`, assert it is a single non-empty string;
      otherwise `cli::cli_abort()`.
    - If `pillar` and `dimension` are both supplied, extract the implied pillar
      from `dimension` (the part before the first `.`) and compare to `pillar`;
      abort with `cli::cli_abort()` if they differ, e.g.:
      `"dimension "2.1" belongs to pillar "2", not "3"."`.
    - If `dimension` and `indicator` are both supplied, verify the indicator row
      exists in the loaded metadata and its `dimension` matches; abort if not.
  - Call `.spi_read_metadata(version = version)` after validation.
  - Build `pillars` data.table: distinct rows on `pillar`, `pillar_name`,
    `pillar_description`, `pillar_id`, ordered by `pillar`.
  - Build `dimensions` data.table: distinct rows on `dimension`, `dimension_name`,
    `dimension_description`, `dimension_id`, `pillar`, ordered by `pillar`,
    `dimension`.
  - Build `indicators` data.table: distinct rows on `indicator`, `indicator_name`,
    `indicator_description`, `indicator_id`, `indicator_scoring`, `indicator_abv`,
    `dimension`, `pillar`, ordered by `pillar`, `dimension`, `indicator`.
  - Apply filters hierarchically:
    - `pillar` supplied: filter all three tables to that pillar.
    - `dimension` supplied: filter all three tables to that dimension (and its
      parent pillar).
    - `indicator` supplied: filter to that indicator row and its parent
      dimension/pillar.
  - If any filtered table is empty, emit `cli::cli_warn()` and keep the empty
    table in the result.
  - Return `list(pillars = ..., dimensions = ..., indicators = ...)`.
  - Add full roxygen2 block with `@param`, `@return`, `@examples`, `@seealso`
    links to `spi_data()`, `spi_indicator()`.
- **Test Scenarios**: pillar only, dimension only, indicator only, pillar +
  dimension consistent, pillar + dimension inconsistent, non-string input,
  no match.
- **Tests**: `tests/testthat/test-spi-metadata.R`
- **Acceptance criteria**: `metadata()` returns a named list of three
  `data.table`s under all valid input combinations and aborts with informative
  messages for all invalid inputs.

### 3. Implement `metadata_pillars()` and `metadata_dimensions()` in `R/spi-wrappers.R`
- **Requirements**: R2, R3, R5, R6, R12
- **Files**: `R/spi-wrappers.R`
- **Details**:
  - `metadata_pillars(version = "master")`:
    - Calls `metadata(version = version)$pillars`.
    - Returns a `data.table` with columns: `pillar`, `pillar_name`,
      `pillar_description`, `pillar_id`, ordered by `pillar`.
  - `metadata_dimensions(pillar = NULL, version = "master")`:
    - Validates `pillar` using the same string rule as `metadata()`.
    - Calls `metadata(pillar = pillar, version = version)$dimensions`.
    - Returns a `data.table` with columns: `pillar`, `dimension`,
      `dimension_name`, `dimension_description`, `dimension_id`,
      ordered by `pillar`, `dimension`.
  - Add roxygen2 blocks for both; include `@seealso [metadata()]`.
- **Test Scenarios**: no filter, valid pillar filter, invalid pillar type.
- **Tests**: `tests/testthat/test-spi-metadata.R`
- **Acceptance criteria**: both wrappers return the correct subset of
  `metadata()` output.

## Phase 2: Tests, Docs, and Export

### 4. Add tests in `tests/testthat/test-spi-metadata.R`
- **Requirements**: R6, R7, R9, R10, R11
- **Files**: `tests/testthat/test-spi-metadata.R`
- **Details**:
  - Create a `mock_metadata_dt` fixture using `data.table::data.table()` with
    at least 2 pillars, 3 dimensions, and 5 indicators, including at least one
    case where a pillar has multiple dimensions.
  - Mock `spi_download` via `local_mocked_bindings(spi_download = ...)` in
    every test block.
  - Test groups:
    - **Input type errors**: `pillar = 1` (integer), `dimension = 2.1` (numeric),
      `pillar = "6"` (out of range), `dimension = "abc"` (bad format).
    - **Hierarchy inconsistency**: `pillar = "3", dimension = "2.1"`.
    - **Pillar-only filter**: output tables contain only rows for that pillar.
    - **Dimension-only filter**: output tables scoped to that dimension and its parent.
    - **Indicator-only filter**: single indicator row + correct parents.
    - **No match**: valid format but absent in mock data → empty tables + warning.
    - **Missing CSV columns**: mock returns dt with one required column dropped →
      `cli::cli_abort()` fires.
    - **Wrappers**: `metadata_pillars()` returns correct columns and order;
      `metadata_dimensions(pillar = "1")` filters correctly.
- **Test Scenarios**: see groups above.
- **Tests**: `testthat::test_file("tests/testthat/test-spi-metadata.R")`
- **Acceptance criteria**: all tests pass without network calls.

### 5. Regenerate package docs and exports
- **Requirements**: R1, R2, R3
- **Files**: `NAMESPACE`, `man/metadata.Rd`, `man/metadata_pillars.Rd`,
  `man/metadata_dimensions.Rd`
- **Details**:
  - Run `roxygen2::roxygenise()` after implementing all three functions.
  - Confirm `NAMESPACE` contains `export(metadata)`,
    `export(metadata_pillars)`, `export(metadata_dimensions)`.
  - Confirm man pages are generated with correct parameter and return
    documentation.
- **Test Scenarios**: package loads cleanly after export.
- **Tests**: `devtools::check()`
- **Acceptance criteria**: `R CMD check` passes with no warnings or errors.

## Testing Strategy
- All tests use `local_mocked_bindings(spi_download = ...)` to avoid network
  calls, following the pattern in `test-spi-wrappers.R`.
- Mock data is a single `data.table` fixture defined once at the top of the
  test file and reused across all test blocks.
- Run focused tests first:
  `testthat::test_file("tests/testthat/test-spi-metadata.R")`.
- Then full suite: `devtools::test()` to confirm no regressions in existing
  wrappers.

## Documentation Checklist
- [ ] roxygen2 block for `metadata()` with `@param`, `@return` (list schema),
  `@examples`, `@seealso`.
- [ ] roxygen2 blocks for `metadata_pillars()` and `metadata_dimensions()`.
- [ ] Regenerate `NAMESPACE` and all `man/*.Rd` files.
- [ ] Confirm `.spi_read_metadata()` has `@keywords internal`.

## Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| `SPI_full_metadata.csv` column names change in a future commit. | Validate required columns on every read; abort with column diff in message. |
| `metadata` name collides with another loaded package. | Name is short by explicit design decision; document namespace conflict in NEWS.md if it occurs. |
| Pillar implied by dimension is extracted by splitting on `.`, which breaks if dimension format changes. | Format is validated by regex before extraction; any change to format will be caught by tests. |
| Mock fixture does not cover edge cases present in real data. | Use at least 2 pillars, 3 dimensions, 5 indicators in fixture; add integration note to run once against live data manually. |
| Tests accidentally hit the network. | Always wrap `spi_download` with `local_mocked_bindings` in every test block. |

## Out of Scope
- Persistent on-disk cache for metadata (beyond the existing in-session download cache).
- `metadata_indicators()` wrapper (avoided to prevent confusion with existing `spi_indicator()`).
- Modifications to `spi_get()`, `spi_indicator()`, or any existing wrapper.
- README or vignette updates.
- Integration with `spi_data()` filtering (metadata lookup only).

## Completion Contract

### Outcome
`metadata()`, `metadata_pillars()`, and `metadata_dimensions()` are implemented,
exported, documented with roxygen2, and fully covered by mocked unit tests.
Users can query the SPI indicator hierarchy with hierarchical consistency
validation and informative `cli` errors.

### Verification Surface
| ID | Evidence Required | Phase | Command/Artifact | Required |
|----|-------------------|-------|-----------------|---------|
| V1 | `metadata(pillar = "1")` returns a list with 3 non-empty data.tables | 1 | manual smoke test | yes |
| V2 | `metadata(dimension = "2.1")` returns pillar "2" in `$pillars` | 1 | manual smoke test | yes |
| V3 | `metadata(pillar = "3", dimension = "2.1")` throws `cli::cli_abort` with hierarchy message | 1 | testthat | yes |
| V4 | Non-string inputs throw `cli::cli_abort` | 1 | testthat | yes |
| V5 | `metadata_pillars()` returns data.table with `pillar`, `pillar_name`, `pillar_description`, `pillar_id` ordered by pillar | 1 | testthat | yes |
| V6 | `metadata_dimensions(pillar = "2")` returns only dimensions belonging to pillar 2 | 1 | testthat | yes |
| V7 | All tests pass without network calls (spi_download mocked) | 2 | `testthat::test_file("tests/testthat/test-spi-metadata.R")` | yes |
| V8 | `NAMESPACE` exports all 3 functions after `roxygen2::roxygenise()` | 2 | `grep "export" NAMESPACE` | yes |
| V9 | `R CMD check` passes with no warnings or errors | final | `devtools::check()` | yes |

### Constraints
| ID | Constraint | Check |
|----|------------|-------|
| C1 | Do not modify `spi_indicator()` or any existing wrapper | diff |
| C2 | No new external dependencies | DESCRIPTION |
| C3 | All filter arguments must be strings | type-check tests |
| C4 | Data source is exclusively `SPI_full_metadata.csv` | code review |
| C5 | data.table backend only, no tidyverse | code review |

### Boundaries
- Allowed: `metadata()`, `metadata_pillars()`, `metadata_dimensions()`,
  `.spi_read_metadata()`, `SPI_METADATA_PATH` constant, new test file, new man pages.
- Out of scope: persistent metadata cache, `metadata_indicators()` wrapper,
  changes to existing wrappers, README, vignette.

### Iteration Policy
1. Missing CSV column → `cli::cli_abort()` listing missing columns and version used.
2. Valid format, no match → empty data.tables + `cli::cli_warn()`.
3. Hierarchical inconsistency → always `cli::cli_abort()`, never warn.
4. `spi_download()` network failure → propagate error as-is (no wrapping needed).

### Blocked-Stop Conditions
- `SPI_full_metadata.csv` does not exist in the `master` branch of worldbank/SPI.
- The name `metadata()` causes an irreconcilable namespace conflict in the test suite.