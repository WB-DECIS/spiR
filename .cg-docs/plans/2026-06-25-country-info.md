---
date: 2026-06-25
title: "Country Info Metadata Wrapper"
status: completed
completed-date: 2026-06-25
completed-phases: [1, 2]
scope: "Standard"
phases: 2
brainstorm: null
language: "R"
estimated-effort: "small"
deviation-policy: "ask"
execution-report: ".cg-docs/work-reports/2026-06-25-country-info.md"
tags: [api, country, metadata, spi-data, wrappers]
---

# Plan: Country Info Metadata Wrapper

## Objective
Add a dedicated API for retrieving country-year metadata columns from the SPI data, such as ISO codes, country name, location, region, income level, lending type, and population. The function should make it easy to build lookup tables for joins, reports, maps, and downstream analysis while preserving metadata changes over time.

## Context
Existing wrapper APIs expose `spi_data()`, `spi_index()`, `spi_aggregates()`, and `spi_indicator()`. The wide `SPI_data.csv` dataset also contains country metadata columns, but there is no direct convenience function for extracting a clean country metadata table. A small wrapper around `spi_get("data", ...)`
keeps the package data-first, avoids new dependencies, and follows the existing wrapper style used by `spi_indicator()`.

The requested output columns are `date` plus:
`iso3c`, `iso2c`, `country`, `capital_city`, `longitude`, `latitude`, `region_iso3c`, `region_iso2c`, `region`, `admin_region_iso3c`, `admin_region_iso2c`, `admin_region`, `income_level_iso3c`, `income_level_iso2c`, `income_level`, `lending_type_iso3c`, `lending_type_iso2c`, `lending_type`, and `population`.

## Requirements
| ID | Requirement | Source |
|----|-------------|--------|
| R1 | Export `country_info()` as a public wrapper function. | User request |
| R2 | Fetch country metadata from `SPI_data.csv` via `spi_get("data", ...)`. | Existing wrapper pattern |
| R3 | Return `date` plus the requested country metadata columns, in a stable order. | User clarification |
| R4 | Support optional `version = "master"`, `country = NULL`, and `year = NULL` arguments. | Existing wrapper pattern |
| R5 | Preserve one row per country-year so metadata changes over time are not lost. | User clarification |
| R6 | Fail loudly with clear errors if required metadata columns are missing. | Project rule |
| R7 | Add unit tests covering successful output, delegation, filtering, ordering, and missing-column errors. | Plan quality |
| R8 | Keep the implementation aligned with data.table style and avoid new dependencies. | Project constraints |

## Phase 1: Core Wrapper

### 1. Implement `country_info()` in `R/spi-wrappers.R`
- **Requirements**: R1, R2, R3, R4, R5, R6, R8
- **Files**: `R/spi-wrappers.R`
- **Details**:
  - Add roxygen2 documentation near the other convenience wrappers.
  - Function signature:
    `country_info <- function(version = "master", country = NULL, year = NULL)`.
  - Call:
    `spi_get(type = "data", version = version, country = country, year = year, pillar = NULL, dimension = NULL)`.
  - Define an internal required-column vector in the function or nearby helper:
    `date`, `iso3c`, `iso2c`, `country`, `capital_city`, `longitude`, `latitude`,
    `region_iso3c`, `region_iso2c`, `region`, `admin_region_iso3c`,
    `admin_region_iso2c`, `admin_region`, `income_level_iso3c`,
    `income_level_iso2c`, `income_level`, `lending_type_iso3c`,
    `lending_type_iso2c`, `lending_type`, `population`.
  - Validate that all required columns exist in the returned data. If any are
    missing, use `cli::cli_abort()` with the missing column names and the
    requested `version`.
  - Subset the data.table to exactly those columns in that order.
  - Preserve one row per available `iso3c`/`date` combination. Do not
    deduplicate to one row per country, because country metadata can change
    across years.
  - Order results deterministically, for example by `iso3c` and `date`.
- **Test Scenarios**: all countries; one country; multiple years; missing
  metadata column.
- **Tests**: `tests/testthat/test-spi-wrappers.R`
- **Acceptance criteria**: `country_info()` returns a `data.table` with exactly
  `date` plus the requested metadata columns, ordered as requested, and preserves
  country-year rows.

## Phase 2: Tests And Documentation Artifacts

### 2. Add wrapper tests in `tests/testthat/test-spi-wrappers.R`
- **Requirements**: R4, R5, R6, R7, R8
- **Files**: `tests/testthat/test-spi-wrappers.R`
- **Details**:
  - Add a mock `spi_get()` or `spi_download()` dataset containing the full set of country metadata columns plus extra SPI indicator columns.
  - Verify `country_info()` calls `spi_get()` with `type = "data"`.
  - Verify `version`, `country`, and `year` are forwarded to `spi_get()`.
  - Verify the output includes `date` plus exactly the required metadata columns in the
    requested order.
  - Verify multiple years for the same country are preserved and identifiable
    through `date`.
  - Verify a missing required metadata column raises an informative error.
- **Test Scenarios**: happy path, filtered country, duplicate years, missing
  column error.
- **Tests**: `testthat::test_file("tests/testthat/test-spi-wrappers.R")`
- **Acceptance criteria**: focused wrapper tests pass without network calls.

### 3. Regenerate package docs and export metadata
- **Requirements**: R1, R7
- **Files**: `NAMESPACE`, `man/country_info.Rd`
- **Details**:
  - Run roxygen2 after implementation so `country_info()` is exported.
  - Confirm `NAMESPACE` contains `export(country_info)`.
  - Confirm generated help documents include parameters, return value, examples,
    and links to related wrapper functions.
- **Test Scenarios**: exported function is available after package load.
- **Tests**: `roxygen2::roxygenise()` and focused wrapper tests.
- **Acceptance criteria**: package metadata reflects the new public API.

## Testing Strategy
- Prefer unit tests with mocked `spi_get()` or `spi_download()` so tests do not
  depend on network access.
- Use self-contained `data.table::data.table()` mock data in
  `tests/testthat/test-spi-wrappers.R`.
- Run focused tests first with:
  `testthat::test_file("tests/testthat/test-spi-wrappers.R")`.
- If focused tests pass, run broader package tests with `devtools::test()` or
  `R CMD check` if available.

## Documentation Checklist
- Add roxygen2 block for `country_info()`.
- Include `@param version`, `@param country`, and `@param year`.
- Document that the function returns one row per country-year and includes
  `date` because metadata such as income level and population can change over
  time.
- Include examples that mirror the wrapper style used by `spi_indicator()`.
- Regenerate `NAMESPACE` and `man/country_info.Rd`.

## Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| Requested columns are not present in all SPI versions. | Fail loudly with missing column names and version context. |
| Multiple years produce repeated countries. | Preserve country-year rows and include `date` so records are interpretable. |
| Metadata values change across years. | Do not deduplicate by country; document that users can pass `year` explicitly. |
| Tests accidentally call the network. | Mock `spi_get()` or `spi_download()` in focused tests. |
| Roxygen output is missed, leaving the function unexported. | Include export verification as required evidence. |

## Out of Scope
- Adding a new external country metadata source or API.
- Changing `spi_get()` filtering semantics.
- Adding map, visualization, or geospatial helpers.
- Adding fuzzy country-name matching.
- Changing the requested metadata column names.