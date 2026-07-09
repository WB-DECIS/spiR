---
date: 2026-06-12
title: "SPI Indicator Selection"
status: active
scope: "Standard"
language: "R"
estimated-effort: "small"
tags: [api, indicator, spi-data, wrappers]
---

# Plan: SPI Indicator Selection

## Objective
Add a dedicated API for requesting named SPI indicator columns directly, such as `SPI.D1.5.POV` or `SPI.D2.1.GDDS`, to make it very easy to extract data for reports and graphs.

## Context
Existing wrapper APIs expose `spi_data()`, `spi_index()`, and `spi_aggregates()`, but there is no direct convenience function for selecting one or more named indicator columns from the wide `SPI_data.csv` dataset. A small wrapper around `spi_get("data", ...)` will keep the package data-first while making indicator-level extraction easier.

## Requirements
- Export `spi_indicator()` from `R/spi-wrappers.R`
- Accept named `SPI.D...` indicators and validate their format
- Fetch `SPI_data.csv` via `spi_get("data", ...)`
- Subset results to identifiers plus requested indicators
- Optionally include corresponding `RAW.D...` columns when `include_raw = TRUE`
- Provide informative errors for invalid or missing indicator names
- Add unit tests covering expected behavior and edge cases

## Implementation steps
1. Implement `spi_indicator()` in `R/spi-wrappers.R`.
   - Arguments: `indicator`, `version = "master"`, `country = NULL`, `year = NULL`, `include_raw = FALSE`.
   - Validate `indicator` as a non-empty character vector with no missing values and valid SPI indicator names.
   - Call `spi_get(type = "data", version = version, country = country, year = year, pillar = NULL, dimension = NULL)`.
   - Subset the returned `data.table` to identifier/metadata columns plus requested `SPI.D...` columns.
   - If `include_raw = TRUE`, also include any matching `RAW.D...` columns.

2. Add tests in `tests/testthat/test-spi-wrappers.R`.
   - Verify requested indicator columns appear in the result.
   - Verify `include_raw = TRUE` adds the corresponding raw columns.
   - Verify invalid indicator names produce informative errors.

3. Keep the new function aligned with the wrapper-style API in `R/spi-wrappers.R` and do not add visualization functionality.

## Acceptance criteria
- `spi_indicator()` exists as a public exported wrapper in `R/spi-wrappers.R`
- It supports direct selection of named `SPI.D...` indicator columns
- It optionally returns `RAW.D...` columns when requested
- It validates input and raises clear errors for invalid or missing indicators
- Tests in `tests/testthat/test-spi-wrappers.R` cover valid selection and error handling
