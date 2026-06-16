# spiR

> R package for accessing [World Bank Statistical Performance Indicators (SPI)](https://github.com/worldbank/SPI) data directly from GitHub.

<!-- badges: start -->
[![R-CMD-check](https://github.com/WB-DECIS/spiR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/WB-DECIS/spiR/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

## Overview

The [Statistical Performance Indicators (SPI)](https://www.worldbank.org/en/programs/statistical-performance-indicators) are an open-source framework developed by the World Bank to assess the performance of national statistical systems. Reliable, high-quality statistics are vital for evidence-based policy and global development, and the SPI provides a transparent, data-driven way to measure how well countries produce and use data. The framework covers **186 countries** and builds on the legacy of the earlier Statistical Capacity Index (SCI), expanding the number of indicators and dimensions considerably. For a full description of the methodology and indicators, see the [SPI Handbook](https://worldbank.github.io/SPI/measuring-the-statistical-performance-of-countries-an-overview-of-the-statistical-performance-indicators-and-index.html#indicator-metadata).

The SPI framework is organized around **five pillars**, each capturing a key aspect of a mature statistical system:

| Pillar | Description |
|--------|-------------|
| 1 | **Data Use** — whether statistics are used widely and frequently |
| 2 | **Data Services** — services connecting data users and producers, building trust |
| 3 | **Data Products** — range and quality of statistical outputs, including SDG reporting |
| 4 | **Data Sources** — availability of censuses, surveys, administrative, and geospatial data |
| 5 | **Data Infrastructure** — legislation, standards, skills, partnerships, and financing |

Each pillar is supported by multiple dimensions and indicators, aggregated into an overall SPI score (0–100) for each country-year. All data and code are published as open data and open code on [GitHub](https://github.com/worldbank/SPI).

`spiR` provides a simple, filter-friendly interface to the three SPI output datasets, with in-session caching to avoid redundant downloads.

## Installation

```r
# Install from GitHub (requires remotes):
remotes::install_github("WB-DECIS/spiR")
```

## Quick Start

```r
library(spiR)

# --- Full datasets ---
spi_data()        # indicator scores per country-year (wide)
spi_index()       # pillar + overall index scores (wide)
spi_aggregates()  # regional aggregates (long)

# --- Filter by country and year ---
spi_data(country = c("NOR", "SWE"), year = 2023L)

# --- Filter by pillar (1–5) ---
spi_data(pillar = 3L)

# --- Filter by dimension (e.g. "5.2") ---
spi_index(dimension = "5.2")

# --- Regional aggregates ---
spi_aggregates(region = "Africa Eastern and Southern", pillar = 1L)

# --- Named indicator columns ---
spi_indicator("SPI.D1.5.POV", country = "CHL", year = 2024L)
spi_indicator(c("SPI.D1.5.POV", "SPI.D2.1.GDDS"), include_raw = TRUE)

# --- Specific version (branch) ---
spi_data(version = "SPI2023")

# --- List available versions ---
spi_versions()

# --- Clear the in-session download cache ---
spi_clear_cache()

# --- Refresh the inventory of available versions from GitHub ---
spi_update_inventory()

# --- Remove the local inventory cache ---
spi_clear_inventory()
```

## Data Types

| Function | Dataset | Format |
|----------|---------|--------|
| `spi_data()` | `SPI_data.csv` | Wide — one row per country-year, all indicator columns |
| `spi_index()` | `SPI_index.csv` | Wide — pillar and overall SPI scores per country-year |
| `spi_aggregates()` | `SPI_databank_country_and_aggregates.csv` | Long — regions only, one row per region-year-indicator |
| `spi_indicator()` | `SPI_data.csv` | Wide — selected indicator columns only (with optional raw values) |

All functions return a [`data.table`](https://r-datatable.com/).

## Filtering Arguments

| Argument | Type | Applies to |
|----------|------|------------|
| `country` | Character vector of ISO 3166-1 alpha-3 codes | `"data"`, `"index"` |
| `region` | Character vector of region names | `"aggregates"` |
| `year` | Integer or numeric vector | All types |
| `pillar` | Integer 1–5 | All types (column filter for `"data"`/`"index"`, row filter for `"aggregates"`) |
| `dimension` | Character `"P.D"` (e.g. `"5.2"`) | All types; overrides `pillar` |
| `version` | Character branch name | All types |

## Versioning

SPI data versions correspond to branches in the [SPI GitHub repository](https://github.com/worldbank/SPI). The default version is `"master"` (latest stable). Use `spi_versions()` to list all available branches.

## Cache & Inventory Management

| Function | Description |
|----------|-------------|
| `spi_clear_cache()` | Clear the in-session download cache |
| `spi_update_inventory()` | Refresh the local inventory of available versions from GitHub |
| `spi_clear_inventory()` | Remove the local inventory cache (forces a fresh fetch on next call) |

## Data Sources

All data originate from the [World Bank SPI GitHub repository](https://github.com/worldbank/SPI), maintained by the DECDG team.

## License

MIT

