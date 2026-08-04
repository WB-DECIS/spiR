# spiR 0.2.0 (2026-08-04)

* Added metadata catalog access through `metadata()`, `metadata_pillars()`,
  `metadata_dimensions()`, and `metadata_indicators()`.
* Added `spi_indicator()` for selecting named indicators and `country_info()`
  for retrieving country-year metadata.
* Added visualization helpers: `spi_plot_pillars()`, `spi_plot_trend()`,
  `spi_plot_country_vs_region()`, `spi_plot_radar()`, `spi_plot_regions()`,
  `spi_plot_region_pillars()`, and `spi_plot_map()` (static `ggplot` or
  interactive `ggiraph` choropleth).
* Region-based plots now use the official SPI regional aggregates from
  `spi_aggregates()`, so they match published values exactly.
* World Bank Data Visualization Style Guide styling (colours + theme) is now
  built into the package. The plot helpers no longer depend on the external,
  non-CRAN `wbplot` package; they only require `ggplot2` (plus `sf`/`ggiraph`
  for maps).
* `spi_clear_geo_cache()`: clear cached map boundary geometries.

# spiR 0.1.0 (2026-04-12)

* First stable release.
* Added vignette "SPI Data Workflows" covering data access, filtering, cross-country
  comparison, and ggplot2 visualization.
* Added pkgdown site at <https://wb-decis.github.io/spiR/>.
* README: added SPI framework overview with links to the
  [SPI program page](https://www.worldbank.org/en/programs/statistical-performance-indicators)
  and [SPI Handbook](https://worldbank.github.io/SPI/measuring-the-statistical-performance-of-countries-an-overview-of-the-statistical-performance-indicators-and-index.html#indicator-metadata).

# spiR 0.0.0.9000

* Initial development release (Milestone 1 — Output Data MVP).
* `spi_get()`: retrieve SPI data, index, or aggregate datasets from GitHub.
* `spi_data()`, `spi_index()`, `spi_aggregates()`: convenience wrappers around `spi_get()`.
* `spi_versions()`: list available SPI data versions (branches) from the SPI GitHub repository.
* `spi_clear_cache()`: clear the in-session download cache.
* `spi_update_inventory()`: refresh the local inventory of available SPI branches from GitHub.
* `spi_clear_inventory()`: remove the local inventory cache.
* Supports filtering by country, year, pillar, dimension, and region.
* In-session caching: repeated calls with the same arguments skip re-download.
* Input validation for all user-facing arguments (type, version, country, region, year, pillar, dimension).
