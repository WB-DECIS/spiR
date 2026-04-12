# spiR 0.0.0.9000

* Initial development release (Milestone 1 — Output Data MVP).
* `spi_get()`: retrieve SPI data, index, or aggregate datasets from GitHub.
* `spi_data()`, `spi_index()`, `spi_aggregates()`: convenience wrappers around `spi_get()`.
* `spi_versions()`: list available SPI data versions (branches) from the SPI GitHub repository.
* `spi_clear_cache()`: clear the in-session download cache.
* Supports filtering by country, year, pillar, dimension, and region.
* In-session caching: repeated calls with the same arguments skip re-download.
* Input validation for all user-facing arguments (type, version, country, region, year, pillar, dimension).
