---
date: 2026-04-10
title: "Milestone 1 API design — spi_get() with convenience wrappers"
status: decided
chosen-approach: "spi_get() umbrella + convenience wrappers"
tags: [api-design, milestone-1, output-data, filtering]
---

# Milestone 1 API Design

## Context

Milestone 1 (Output Data Access MVP) needs a clear public API for retrieving
the three core SPI output files from the worldbank/SPI GitHub repository.
The data files have different structures that affect how filtering works:

- **SPI_data.csv**: Wide format. Columns: `iso3c`, `date`, ~90 indicator
  columns (prefixed `SPI.D*` and `RAW.D*`), plus metadata (country, region,
  income_level, etc.). Pillar/dimension encoded in column names
  (e.g., `SPI.D3.5.GEND` = Pillar 3, Dimension 5).
- **SPI_index.csv**: Wide format. Columns: `country`, `iso3c`, `date`,
  pillar indices (`SPI.INDEX.PIL1`–`PIL5`), overall `SPI.INDEX`, dimension
  indices, individual indicators, plus `income`, `region`, `weights`,
  `population`.
- **SPI_databank_country_and_aggregates.csv**: Long format. Columns:
  `iso3c`, `country`, `date`, `source_id`, `source_name`, `N`, `N_obs`,
  `value`, `footnote`. Contains both countries and regional aggregates.

Key design decisions established during discussion:

1. Default branch is `master` (matching the SPI repo).
2. Filtering on data/index = column subsetting by pillar/dimension +
   row filtering by country/year.
3. Filtering on aggregates = row filtering by region/year/pillar/dimension.
   Aggregates returns **only regions** (no individual countries).
4. `country` parameter for data/index; `region` parameter for aggregates.
   Passing `country` to aggregates produces an informative error.
5. `readxl` will be used for `.xlsx` files (scoped to Milestone 2).

## Requirements

1. `spi_get(type, ...)` as the primary workhorse function.
2. Convenience wrappers: `spi_data()`, `spi_index()`, `spi_aggregates()`.
3. Each wrapper has a clean signature with only the arguments relevant to
   that data type.
4. Internal download engine fetches CSV from raw GitHub URLs with error
   handling and version (branch) support.
5. `spi_versions()` queries GitHub API for available branches.
6. Filtering arguments:
   - `country` (character vector of ISO3C codes) — data/index only
   - `year` (integer vector) — all types
   - `pillar` (integer 1–5) — all types (column subsetting on data/index,
     row filtering on aggregates via `source_id` prefix)
   - `dimension` (character like "5.2") — all types (same logic as pillar)
   - `region` (character vector) — aggregates only
7. All functions return `data.table`.
8. Version defaults to `"master"`.

## Approaches Considered

### Approach 1: Single `spi_get()` with type-aware arguments

One exported function handles all three files; arguments that don't apply
to a given type are validated and rejected.

- **Pros**: Simple API surface — one function to learn.
- **Cons**: Busy signature (type, version, country, year, pillar, dimension,
  region). `country` vs `region` distinction may confuse users.
- **Effort**: Medium

### Approach 2: Separate functions per type

Three exported functions — `spi_data()`, `spi_index()`, `spi_aggregates()`.

- **Pros**: Clean signatures. No type dispatching. Easy to document.
- **Cons**: Three functions to remember. Shared download logic must be
  well-factored.
- **Effort**: Medium

### Approach 3: `spi_get()` umbrella + convenience wrappers

`spi_get()` does the heavy lifting; thin wrappers `spi_data()`,
`spi_index()`, `spi_aggregates()` are exported as shortcuts.

- **Pros**: Best of both worlds — power users use `spi_get()`, casual users
  use named functions. Each wrapper has a clean signature.
- **Cons**: More exported functions to maintain and test.
- **Effort**: Medium-large

## Decision

**Approach 3: `spi_get()` umbrella + convenience wrappers.** Provides
maximum flexibility: `spi_get()` for programmatic use and consistency,
named wrappers for discoverability and clean signatures.

## Next Steps

1. Implement internal download engine (`spi_download` or similar).
2. Implement `spi_get()` with full filtering logic.
3. Implement `spi_data()`, `spi_index()`, `spi_aggregates()` wrappers.
4. Implement `spi_versions()` using GitHub API.
5. Write tests for all exported functions.
6. Finalize package infrastructure (DESCRIPTION, NAMESPACE, roxygen2).
