# SPI Indicator Selection Plan

## Objective
Add a dedicated API for requesting named SPI indicator columns directly, such as `SPI.D1.5.POV` or `SPI.D2.1.GDDS`, to make it very easy to extract data for reports and graphs.

## Background
Current SPI wrapper APIs expose `spi_data()`, `spi_index()`, and `spi_aggregates()`, but there is no direct convenience function for selecting one or more named indicator columns from the wide `SPI_data.csv` dataset.

## Scope
- Implement `spi_indicator()` in `R/spi-wrappers.R`
- Ensure it is a thin wrapper around `spi_get("data", ...)`
- Validate the requested indicator names and surface helpful errors for invalid or missing columns
- Optionally return raw indicator values when `include_raw = TRUE`
- Add tests in `tests/testthat/test-spi-wrappers.R`

## Implementation steps
1. Add `spi_indicator()` to `R/spi-wrappers.R`.
   - Accept `indicator`, `version`, `country`, `year`, and `include_raw`.
   - Validate `indicator` as a non-empty character vector of valid SPI indicator column names.
   - Call `spi_get(type = "data", ...)` to fetch `SPI_data.csv`.
   - Subset the result to identifier and requested indicator columns.
   - If `include_raw = TRUE`, include matching `RAW.D...` columns when present.

2. Add tests for `spi_indicator()`.
   - Confirm it returns the requested indicator columns.
   - Confirm `include_raw = TRUE` returns `RAW.D...` columns.
   - Confirm invalid indicator names raise an informative error.

3. Keep the package data-first and avoid adding visualization APIs here.

## Acceptance criteria
- `spi_indicator()` exists as a public wrapper in `R/spi-wrappers.R`
- It can fetch named indicator columns directly
- It supports `include_raw` correctly
- Unit tests cover valid selection and error handling
- The plan is recorded in `.cg-docs/plans/2026-06-12-spi-indicator-selection.md`
