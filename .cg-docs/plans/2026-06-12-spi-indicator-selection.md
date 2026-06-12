---
date: 2026-06-12
title: "SPI Indicator Selection — Direct Indicator Access"
status: active
brainstorm: null
language: "R"
estimated-effort: "small"
tags: [spi-get, spi-indicator, data-access, enhancement]
---

# Plan: SPI Indicator Selection — Direct Indicator Access

## Objective

Add a dedicated API to request one or more named SPI indicators directly by column name, without requiring manual subsetting after `spi_data()`.

The new function `spi_indicator()` should allow users to retrieve selected indicator columns such as `SPI.D1.5.POV` or `SPI.D2.1.GDDS` with the same filtering flexibility already available for country, year, and version. This closes the current gap where indicator selection stops at dimension level.

## Context

**Current behavior:**
- `spi_data()` and `spi_index()` support filtering by country, year, pillar, or dimension.
- Data is stored in wide form with ~100+ indicator columns named like `SPI.D{pillar}.{dimension}.{code}` and matching `RAW.D...` columns.
- Users who want a specific indicator must call `spi_data()` and then subset columns manually.

**Problem:**
- The package does not expose a direct indicator selection API.
- This creates friction for report generation and indicator-specific analysis.
- A dedicated function will make the package easier to use and more consistent with the package’s goal of providing data-first access.

**Existing files and behavior to extend:**
- `R/spi-data.R` contains `spi_get()` and filters by pillar/dimension.
- `R/spi-wrappers.R` exposes convenience wrappers like `spi_data()` and `spi_index()`.
- `R/spi-filters.R` contains internal helpers for column filtering.
- `tests/testthat/test-spi-data.R` and `tests/testthat/test-spi-wrappers.R` cover current filtering behavior.

## Implementation Steps

### 1. Define `spi_indicator()` interface

- **Signature suggestion:**
  ```r
  spi_indicator(
    indicator,
    version = "master",
    country = NULL,
    year = NULL,
    include_raw = FALSE
  )
  ```

- `indicator`: character scalar or vector of SPI indicator column names.
- `version`: branch name, default `"master"`.
- `country`: optional ISO3 country filter.
- `year`: optional year filter.
- `include_raw`: logical, whether to also return matching `RAW.D...` columns.

### 2. Validate inputs

- `indicator` must be a non-empty character vector with no NAs.
- If `country` is provided, it must be a character vector with valid ISO3 strings.
- If `year` is provided, it must be numeric/integer with no NAs.
- `include_raw` must be logical of length 1.

### 3. Load the correct dataset

- Use `spi_get("data", version = version, country = country, year = year, pillar = NULL, dimension = NULL)` internally.
- This preserves existing data access and caching behavior.

### 4. Select requested indicator columns

- Always keep identifier columns: `iso3c`, `country`, `date`, and any metadata columns required for downstream use.
- Keep requested `SPI.D...` columns.
- If `include_raw = TRUE`, also keep corresponding `RAW.D...` columns for each requested SPI indicator.
- If a requested indicator column does not exist in the downloaded data, return a clear error listing the invalid names.

### 5. Preserve expected output shape

- If the user requests multiple indicators, return all matching columns.
- If user requests a single indicator, return a `data.table` with the same row count as the filtered dataset.
- Keep the original row ordering from `spi_get()`.

### 6. Add a convenience wrapper

- Optionally expose `spi_indicator()` directly as part of the public API.
- Add roxygen2 documentation and `@export`.
- Example usage:
  ```r
  spi_indicator("SPI.D1.5.POV", country = "CHL", year = 2024)
  spi_indicator(c("SPI.D1.5.POV", "SPI.D2.1.GDDS"), include_raw = TRUE)
  ```

## Testing

### New tests to add

- `tests/testthat/test-spi-indicator.R` (recommended)
  - Single indicator selection returns identifier columns + requested column.
  - Multiple indicator selection returns all requested columns.
  - `include_raw = TRUE` returns matching `RAW.D...` columns.
  - Invalid indicator name errors clearly with the invalid column listed.
  - Filtering by `country` and `year` still works.

### Add coverage to existing mocks
n- Reuse the existing mock `spi_download()` in `test-spi-data.R` or `test-spi-indicator.R`.
- Create a small wide data.table fixture with a few `SPI.D...` and `RAW.D...` columns.

## Deliverables

- New public function `spi_indicator()`.
- Tests covering direct indicator selection and error handling.
- Documentation example in package help.
- Minimal changes to existing data access logic.

## Acceptance criteria

- Users can request indicator columns directly by name.
- `spi_indicator("SPI.D1.5.POV")` returns the expected wide dataset with identifiers.
- `spi_indicator(..., include_raw = TRUE)` returns both SPI and raw indicator columns.
- Missing indicator names produce a helpful error.
- Existing `spi_data()`/`spi_index()` behavior is unchanged.

## Notes

This task is intentionally narrow and focused: it does not require new visualization support, only a cleaner API for the existing wide-format SPI data. It is a strong fit for the package’s data-first objective.
