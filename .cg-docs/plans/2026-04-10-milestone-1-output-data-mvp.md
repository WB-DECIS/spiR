---
date: 2026-04-10
title: "Milestone 1 — Output Data Access MVP"
status: active
brainstorm: ".cg-docs/brainstorms/2026-04-10-milestone-1-api-design.md"
language: "R"
estimated-effort: "medium"
tags: [milestone-1, output-data, spi-get, filtering, package-infrastructure]
---

# Plan: Milestone 1 — Output Data Access MVP

## Objective

Implement the full Milestone 1 deliverable: users can retrieve SPI_data.csv,
SPI_index.csv, and regional aggregates from the worldbank/SPI GitHub repo,
with filtering by country/region, year, pillar, and dimension, plus version
(branch) support. The API exposes `spi_get()` as the workhorse and
`spi_data()`, `spi_index()`, `spi_aggregates()` as convenience wrappers.

## Context

**What exists today:**
- Skeleton package: DESCRIPTION, LICENSE, `R/spiR-package.R`, `R/spi-data.R`
  with placeholder `spi_get()`, `spi_versions()`, `spi_inventory()`.
- Placeholder tests in `tests/testthat/test-spi-data.R` (5 tests, no
  network calls).
- Default version is currently `"main"` — must change to `"master"`.
- `spi_get()` currently uses `utils::read.csv()` and doesn't filter.
- `spi_inventory()` returns a hardcoded data.table (Milestone 2 scope).

**Data structures (from GitHub inspection):**
- **SPI_data.csv** (wide): `iso3c`, `date`, `SPI.D{P}.{D}.*` indicators,
  `RAW.D*` columns, metadata (`country`, `region`, `income_level`, etc.).
  ~90 indicator + ~20 metadata columns. Rows = country-years.
- **SPI_index.csv** (wide): `country`, `iso3c`, `date`,
  `SPI.INDEX.PIL{1-5}`, `SPI.INDEX`, `SPI.DIM{P}.{D}.INDEX`, individual
  indicators, `income`, `region`, `weights`, `population`.
  Rows = country-years.
- **SPI_databank_country_and_aggregates.csv** (long): `iso3c`, `country`,
  `date`, `source_id`, `source_name`, `N`, `N_obs`, `value`, `footnote`.
  Contains both individual countries and regional aggregates.

**Pillar/dimension encoding in column names:**
- `SPI.D1.*` = Pillar 1 (Data Use), `SPI.D2.*` = Pillar 2 (Data Services),
  ..., `SPI.D5.*` = Pillar 5 (Data Infrastructure)
- `SPI.D{P}.{D}.*` encodes dimension — e.g. `SPI.D5.2.1.SNAU` =
  Pillar 5, Dimension 2, sub-indicator 1

**Key decisions from brainstorm:**
- Approach 3: `spi_get()` umbrella + `spi_data()`/`spi_index()`/
  `spi_aggregates()` convenience wrappers.
- `country` param for data/index; `region` param for aggregates.
- Pillar/dimension filtering = column subsetting on data/index,
  row filtering on aggregates (via `source_id` prefix).
- Aggregates returns region rows only (no individual countries).
- Default version = `"master"` (the SPI repo default branch).
- Use `data.table::fread()` for CSV reading (faster, more robust).

## Implementation Steps

### 1. Internal download engine — `spi_download()`

- **Files**: `R/spi-download.R` (new)
- **Details**:
  - Non-exported function `spi_download(file_path, version = "master")`.
  - Constructs URL:
    `https://raw.githubusercontent.com/worldbank/SPI/{version}/{file_path}`.
  - Downloads to a tempfile, reads with `data.table::fread()`.
  - Returns a `data.table`.
  - Graceful error handling: wrap in `tryCatch`, produce informative
    error with the URL, version, and original error message.
  - Validate `version` is a single non-empty character string.
- **Tests**: `tests/testthat/test-spi-download.R`
  - URL construction is correct for different versions.
  - Invalid version input produces informative error.
  - Network failure produces informative error (mock with
    `local_mocked_bindings`).
- **Acceptance criteria**: `spi_download("03_output_data/SPI_data.csv")`
  returns a data.table with expected columns. Error messages are clear.

### 2. Pillar/dimension column-filtering helpers

- **Files**: `R/spi-filters.R` (new)
- **Details**:
  - Non-exported helper `filter_columns_by_pillar(dt, pillar)`:
    - Keeps identifier columns (`iso3c`, `date`, `country`, etc.) plus
      columns matching `SPI.D{pillar}.*` and `RAW.D{pillar}.*` patterns.
    - `pillar` is integer 1–5; NULL means no filtering.
  - Non-exported helper `filter_columns_by_dimension(dt, dimension)`:
    - `dimension` is character like `"5.2"` → keeps columns matching
      `SPI.D5.2.*` and `RAW.D5.2.*`.
    - NULL means no filtering.
  - Non-exported helper `filter_rows_by_pillar_dimension(dt, pillar, dimension)`:
    - For aggregates (long format): filters `source_id` column.
    - pillar → `source_id` starts with `SPI.D{pillar}.`
    - dimension → `source_id` starts with `SPI.D{P}.{D}.`
  - Non-exported helper `identify_id_columns(dt)`:
    - Returns character vector of non-indicator columns (identifiers and
      metadata) that should always be preserved during column filtering.
    - Logic: columns NOT starting with `SPI.` or `RAW.` are identifiers.
    - For SPI_index.csv, also preserve `SPI.INDEX*` columns.
  - Non-exported helper `identify_aggregate_regions(dt)`:
    - For the aggregates file, distinguish region rows from country rows.
    - Strategy: use the known WB aggregate ISO3C codes (3-letter codes
      that represent regions/income groups, not countries). These are
      identifiable because they appear in the aggregates file and do NOT
      appear in SPI_data.csv as individual countries. Alternatively,
      simpler: keep rows where `iso3c` length is 3 AND the code matches
      known WB aggregate patterns (starts with common prefixes or is in
      a maintained list).
    - Pragmatic approach: countries always have standard ISO 3166-1 alpha-3
      codes. WB aggregates use codes like `AFE`, `AFW`, `ARB`, `CEB`,
      `CSS`, `EAP`, `EAR`, `EAS`, `ECA`, `ECS`, `EMU`, `FCS`, etc.
      Use a lookup: download the full file, then identify rows where
      `iso3c` appears in `SPI_data.csv`'s `iso3c` column as countries.
      Aggregates = rows whose `iso3c` is NOT a country code.
    - Even simpler: the aggregates file's `country` column has region names
      like "Africa Eastern and Southern". Use a curated list of WB
      aggregate codes shipped as internal package data.
- **Tests**: `tests/testthat/test-spi-filters.R`
  - Column filtering by pillar keeps correct columns.
  - Column filtering by dimension keeps correct columns.
  - Identifier columns are always preserved.
  - Row filtering on aggregates by pillar/dimension works.
  - Edge cases: invalid pillar (6, 0, -1), invalid dimension format.
- **Acceptance criteria**: Given a sample data.table mimicking SPI_data
  columns, `filter_columns_by_pillar(dt, 3)` returns only Pillar 3
  indicator columns plus identifiers.

### 3. Region identification — internal data

- **Files**: `R/sysdata.R` or `data-raw/aggregate_codes.R` (new),
  `R/spi-filters.R` (update)
- **Details**:
  - Create a character vector `spi_aggregate_codes` of known WB aggregate
    ISO3C codes. Store as internal package data via `usethis::use_data(internal = TRUE)`
    or hardcode in `R/spi-filters.R` as a package-level constant.
  - Hardcoding is simpler and avoids `data-raw/` complexity. The list
    changes rarely.
  - Source: extract from the aggregates file itself — all `iso3c` values
    that are NOT standard country codes.
- **Tests**: Covered in Step 2 tests.
- **Acceptance criteria**: `is_aggregate_code("AFE")` returns TRUE;
  `is_aggregate_code("NOR")` returns FALSE.

### 4. Core `spi_get()` rewrite

- **Files**: `R/spi-data.R` (rewrite `spi_get()`)
- **Details**:
  - New signature: `spi_get(type = "data", version = "master", country = NULL,
    year = NULL, pillar = NULL, dimension = NULL, region = NULL)`.
  - Remove the `raw` parameter (not needed for MVP).
  - `type = match.arg(type, c("data", "index", "aggregates"))`.
  - Map type to file path:
    - `"data"` → `"03_output_data/SPI_data.csv"`
    - `"index"` → `"03_output_data/SPI_index.csv"`
    - `"aggregates"` → `"03_output_data/SPI_databank_country_and_aggregates.csv"`
  - Validate argument combinations:
    - `country` + `type = "aggregates"` → error: "Use 'region' to filter
      aggregates, not 'country'."
    - `region` + `type %in% c("data", "index")` → error: "Use 'country'
      to filter data/index, not 'region'."
    - `pillar` not in 1:5 → error.
    - `dimension` not matching `"^\\d+\\.\\d+$"` → error.
  - Call `spi_download()` to fetch the data.
  - Apply filters:
    - For data/index: filter rows by `country` (on `iso3c`), `year`
      (on `date`), then filter columns by `pillar`/`dimension`.
    - For aggregates: first remove country rows (keep only aggregate
      codes), then filter rows by `region` (on `country` column),
      `year` (on `date`), `pillar`/`dimension` (on `source_id`).
  - Return `data.table`.
- **Tests**: `tests/testthat/test-spi-data.R` (rewrite)
  - Argument validation: invalid type, invalid country+aggregates combo,
    invalid region+data combo, invalid pillar, invalid dimension.
  - Integration tests (with mocked download): correct filtering by
    country, year, pillar, dimension.
  - Aggregates: only regions returned, country rows excluded.
- **Acceptance criteria**: `spi_get("data", country = "NOR", year = 2024,
  pillar = 3)` returns a data.table with only Norway 2024 rows and
  Pillar 3 columns.

### 5. Convenience wrappers

- **Files**: `R/spi-wrappers.R` (new)
- **Details**:
  - `spi_data(version = "master", country = NULL, year = NULL,
    pillar = NULL, dimension = NULL)` — calls
    `spi_get("data", version, country, year, pillar, dimension)`.
  - `spi_index(version = "master", country = NULL, year = NULL,
    pillar = NULL, dimension = NULL)` — calls
    `spi_get("index", ...)`.
  - `spi_aggregates(version = "master", region = NULL, year = NULL,
    pillar = NULL, dimension = NULL)` — calls
    `spi_get("aggregates", version, region = region, year = year,
    pillar = pillar, dimension = dimension)`.
  - Each has full roxygen2 documentation with examples.
  - `@export` all three.
- **Tests**: `tests/testthat/test-spi-wrappers.R`
  - Each wrapper calls `spi_get()` with correct arguments (mock
    `spi_get` to verify).
  - `spi_data()` does not accept `region`.
  - `spi_aggregates()` does not accept `country`.
- **Acceptance criteria**: `spi_data(country = "NOR")` is equivalent
  to `spi_get("data", country = "NOR")`.

### 6. `spi_versions()` implementation

- **Files**: `R/spi-data.R` (rewrite `spi_versions()`)
- **Details**:
  - Uses GitHub API: `GET https://api.github.com/repos/worldbank/SPI/branches`
  - Parse JSON response (use `jsonlite::fromJSON()` — add to Imports,
    or use base R `read.csv` on the API... no, JSON needs a parser).
  - Alternative: avoid `jsonlite` dependency by parsing with
    `utils::URLencode` + regex on raw response. But `jsonlite` is
    lightweight and standard — acceptable dependency.
  - Return character vector of branch names.
  - Graceful error on network failure.
  - `@export`.
- **Tests**: `tests/testthat/test-spi-versions.R`
  - Returns character vector (mocked).
  - Network error handled gracefully.
- **Acceptance criteria**: `spi_versions()` returns a character vector
  including `"master"`.

### 7. Package infrastructure cleanup

- **Files**: `DESCRIPTION`, `R/spiR-package.R`, `NAMESPACE` (via roxygen2)
- **Details**:
  - Update DESCRIPTION: add `jsonlite` to Imports. Ensure `Config/testthat/edition: 3`.
  - Update `R/spiR-package.R` to use `@importFrom` instead of blanket
    `@import data.table` if preferred, or keep `@import data.table`.
  - Run `devtools::document()` to rebuild NAMESPACE.
  - Run `devtools::check()` — target 0 errors, 0 warnings, minimal notes.
  - Remove placeholder `spi_inventory()` from `R/spi-data.R` (Milestone 2).
- **Tests**: No new tests; existing tests must pass.
- **Acceptance criteria**: `R CMD check` passes with 0 errors, 0 warnings.

### 8. Comprehensive test suite

- **Files**: All test files from steps above, consolidated.
- **Details**:
  - **Unit tests** (no network): argument validation, column filtering
    logic, region identification, wrapper delegation. Use small
    hand-crafted data.tables that mimic the real column structure.
  - **Integration tests** (with network, skipped on CRAN): actual
    downloads of SPI_data, SPI_index, aggregates. Verify structure,
    filtering, and region-only behavior. Wrap in
    `skip_if_offline()` / `skip_on_cran()`.
  - Target: >80% coverage of exported function logic.
- **Acceptance criteria**: `devtools::test()` passes, all tests green.

## Testing Strategy

- **No network in unit tests**: Mock `spi_download()` using
  `testthat::local_mocked_bindings()` for all filtering/wrapper tests.
  Build small data.tables with representative column names.
- **Integration tests**: Separate test file (`test-integration.R`) with
  `skip_if_offline()`. These hit GitHub and verify real data structure.
- **Edge cases to cover**:
  - Empty result after filtering (no matching country/year).
  - All pillars requested (NULL = no filter).
  - Multiple countries, multiple years.
  - Aggregates: verify no country rows leak through.
  - Invalid version branch → informative error.
  - Dimension "1.5" vs pillar 1 — ensure no confusion.

## Documentation Checklist

- [ ] `spi_get()` roxygen2: all params, return value, 3+ examples
- [ ] `spi_data()` roxygen2: params, return, examples
- [ ] `spi_index()` roxygen2: params, return, examples
- [ ] `spi_aggregates()` roxygen2: params, return, examples
- [ ] `spi_versions()` roxygen2: params, return, examples
- [ ] `spi_download()` internal docs (not exported, but documented)
- [ ] Filter helpers: internal docs
- [ ] DESCRIPTION: accurate description, correct Imports
- [ ] Inline comments for pillar/dimension regex logic

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| GitHub API rate limiting on `spi_versions()` | Document that unauthenticated limit is 60/hr; sufficient for interactive use |
| Aggregates file column structure changes | Tests verify expected columns; informative error if columns missing |
| Region vs country identification breaks | Hardcoded aggregate code list; easy to update; integration tests catch drift |
| Large CSV download time | `fread()` is fast; document that first call downloads; consider caching in Milestone 2 |
| `jsonlite` dependency bloat | `jsonlite` is tiny (~300KB), already used by most R data packages |

## Out of Scope

- Raw data retrieval (`spi_get_raw()`) — Milestone 2
- Interactive inventory (`spi_inventory()`) — Milestone 2
- Data caching / offline mode — Milestone 2
- `.xlsx` file support — Milestone 2
- README rewrite — Milestone 3
- Vignettes — Milestone 3
