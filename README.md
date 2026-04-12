# spiR

> R package for accessing [World Bank Statistical Performance Indicators (SPI)](https://github.com/worldbank/SPI) data directly from GitHub.

<!-- badges: start -->
[![R-CMD-check](https://github.com/WB-DECIS/spiR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/WB-DECIS/spiR/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

## Overview

The SPI framework measures the capacity of national statistical systems across five pillars:

| Pillar | Description |
|--------|-------------|
| 1 | Data Use |
| 2 | Data Services |
| 3 | Data Products |
| 4 | Data Sources |
| 5 | Data Infrastructure |

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

# --- Specific version (branch) ---
spi_data(version = "SPI2023")

# --- List available versions ---
spi_versions()

# --- Clear the in-session download cache ---
spi_clear_cache()
```

## Data Types

| Function | Dataset | Format |
|----------|---------|--------|
| `spi_data()` | `SPI_data.csv` | Wide — one row per country-year, indicator columns |
| `spi_index()` | `SPI_index.csv` | Wide — pillar and overall SPI scores per country-year |
| `spi_aggregates()` | `SPI_databank_country_and_aggregates.csv` | Long — regions only, one row per region-year-indicator |

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

## Data Sources

All data originate from the [World Bank SPI GitHub repository](https://github.com/worldbank/SPI), maintained by the DECDG team.

## License

MIT

