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

`spiR` provides a simple, filter-friendly interface to the SPI output
datasets and country metadata wrappers, with in-session caching to avoid
redundant downloads.

`spiR` also supports metadata access workflows, so you can inspect available
pillars, dimensions, and indicators before pulling data values.

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

# --- Changes over time ---
scores <- spi_change(spi_index(country = "KEN"))
scores[, .(date, SPI.INDEX, change_previous, change_first)]

# --- Country-year metadata ---
country_info(country = "CHL", year = 2024L)

# --- Metadata catalog access ---
metadata(pillar = "1")
metadata(pillar = "SPI.INDEX.PIL1")
metadata(dimension = "SPI.DIM1.5.INDEX")
metadata_pillars()
metadata_dimensions(pillar = "2")

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

## Visualization Helpers

`spiR` includes high-level plotting helpers for the most common SPI
comparison workflows. These functions fetch the needed SPI data, reshape it,
and return ready-to-use `ggplot2` objects. The map helper can also return an
interactive widget.

| Function | Purpose | Output |
|----------|---------|--------|
| `spi_plot_pillars()` | Plot the five SPI pillars over time for one country | `ggplot` |
| `spi_plot_trend()` | Compare one SPI series across multiple countries over time | `ggplot` |
| `spi_plot_country_vs_region()` | Compare one country against its official regional aggregate | `ggplot` |
| `spi_plot_radar()` | Show one country's pillar profile versus its region in one year | `ggplot` |
| `spi_plot_regions()` | Compare one SPI series across regions over time | `ggplot` |
| `spi_plot_region_pillars()` | Plot pillar trends for one region using official SPI aggregates | `ggplot` |
| `spi_plot_map()` | Draw a world choropleth for any SPI column | `ggplot` or `girafe` |

### Change calculations

Use `spi_change()` to add changes from the previous and first valid data years
to an SPI score table. It works with the wide output of `spi_index()` or with
any data frame that has a score column, a year column, and one or more grouping
columns. Missing calendar years are skipped, so changes are calculated between
the available valid observations rather than between assumed consecutive years.

```r
ken <- spi_index(country = "KEN")
ken_changes <- spi_change(ken)

# Use a pillar score and group several countries
country_changes <- spi_change(
	spi_index(country = c("KEN", "UGA")),
	value_col = "SPI.INDEX.PIL1",
	group_cols = "iso3c",
	year_col = "date"
)
```

The returned table preserves the input columns and adds:

| Column | Meaning |
|---|---|
| `change_previous` | Difference from the previous valid year for the same group |
| `change_first` | Difference from the first valid year for the same group |

The first valid observation has `change_previous = NA` and
`change_first = 0`. Rows with missing years or scores receive `NA` changes.

```r
# Country pillar trajectories
spi_plot_pillars(country = "CHL")

# Multi-country trend comparison
spi_plot_trend(countries = c("CHL", "PER"), value_col = "SPI.INDEX")

# Country versus regional average
spi_plot_country_vs_region(country = "CHL", value_col = "SPI.INDEX.PIL1")

# Country radar profile for one year
spi_plot_radar(country = "CHL", year = 2024L)

# Region comparisons
spi_plot_regions(value_col = "SPI.INDEX")
spi_plot_region_pillars(region = "Latin America & Caribbean")

# Static or interactive maps
spi_plot_map(value_col = "SPI.INDEX", year = 2024L, interactive = FALSE)
spi_plot_map(value_col = "SPI.INDEX", year = 2024L, interactive = TRUE)
```

All plotting helpers require `ggplot2`, and time-series plotting helpers also
require `ggrepel` for latest-value endpoint labels. `spi_plot_map()` also
requires `sf`, and interactive maps additionally require `ggiraph`. The World
Bank Data Visualization Style Guide styling is built into the package, so no
external styling package is needed.

Time-series helpers (`spi_plot_pillars()`, `spi_plot_trend()`,
`spi_plot_country_vs_region()`, `spi_plot_regions()`, and
`spi_plot_region_pillars()`) now:

- start the x-axis at the previous five-year interval that contains the first
	non-missing observation;
- keep enough right-side x-scale space so the final year tick is fully visible;
- label only the latest non-missing value in each series (ISO3 for countries,
	aggregate codes for regions, and SPI source codes for SPI series);
- use metadata-derived SPI names in titles and legends (for example,
	`SPI.INDEX` as "SPI Index" and `SPI.INDEX.PIL1` as "Pillar 1: Data Use").

## Data Types

| Function | Dataset | Format |
|----------|---------|--------|
| `spi_data()` | `SPI_data.csv` | Wide — one row per country-year, all indicator columns |
| `spi_index()` | `SPI_index.csv` | Wide — pillar and overall SPI scores per country-year |
| `spi_aggregates()` | `SPI_databank_country_and_aggregates.csv` | Long — aggregate/group rows only, one row per aggregate-year-indicator |
| `spi_indicator()` | `SPI_data.csv` | Wide — selected indicator columns only (with optional raw values) |
| `country_info()` | `SPI_data.csv` | Wide — country-year metadata columns only |
| `metadata()` | SPI metadata catalog | List of tables — pillars, dimensions, indicators |
| `metadata_pillars()` | SPI metadata catalog | Wide — pillar metadata only |
| `metadata_dimensions()` | SPI metadata catalog | Wide — dimension metadata only |

`metadata()` returns a named list of [`data.table`](https://r-datatable.com/)
objects. The other accessors return a single `data.table`.

## Filtering Arguments

| Argument | Type | Applies to |
|----------|------|------------|
| `country` | Character vector of ISO 3166-1 alpha-3 codes | `"data"`, `"index"`, `country_info()` |
| `region` | Character vector of region names | `"aggregates"` |
| `year` | Integer or numeric vector | All types |
| `pillar` | Integer 1–5 | All types (column filter for `"data"`/`"index"`, row filter for `"aggregates"`) |
| `dimension` | Character `"P.D"` (e.g. `"5.2"`) | All types; overrides `pillar` |
| `indicator` | Character vector of `SPI.D...` codes | `spi_indicator()` only |
| `include_raw` | Logical scalar | `spi_indicator()` only; also return matching `RAW.D...` columns |

For metadata accessors, `pillar` and `dimension` accept either the canonical
package-facing values (for example `"1"` and `"1.5"`) or the SPI metadata IDs
(`"SPI.INDEX.PIL1"`, `"SPI.DIM1.5.INDEX"`). Indicator filters accept SPI
indicator codes such as `"SPI.D1.5.POV"`.
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

