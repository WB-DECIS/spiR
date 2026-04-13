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
