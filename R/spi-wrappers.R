# Convenience wrappers around spi_get(). Each function has a focused
# signature with only the arguments relevant to that data type.

#' Retrieve SPI indicator data
#'
#' A convenience wrapper around `spi_get("data", ...)` that retrieves
#' `SPI_data.csv` — individual indicator scores per country-year in wide
#' format.
#'
#' @inheritParams spi_get
#' @param country Character vector of ISO 3166-1 alpha-3 country codes (e.g.
#'   `c("NOR", "SWE")`). `NULL` returns all countries.
#'
#' @return A `data.table` in wide format with one row per country-year.
#'   Columns include `iso3c`, `date`, all `SPI.D*`/`RAW.D*` indicator
#'   columns, and country metadata.
#'
#' @seealso [spi_index()], [spi_aggregates()], [spi_get()], [spi_versions()]
#'
#' @examples
#' \dontrun{
#' # All countries, all years
#' spi_data()
#'
#' # Single country, multiple years
#' spi_data(country = "NOR", year = 2020:2024)
#'
#' # Only Pillar 3 (Data Products) columns
#' spi_data(pillar = 3)
#'
#' # Specific dimension
#' spi_data(dimension = "4.1")
#' }
#'
#' @export
spi_data <- function(version = "master",
                     country = NULL,
                     year = NULL,
                     pillar = NULL,
                     dimension = NULL) {
  spi_get(
    type      = "data",
    version   = version,
    country   = country,
    year      = year,
    pillar    = pillar,
    dimension = dimension
  )
}

#' Retrieve SPI index scores
#'
#' A convenience wrapper around `spi_get("index", ...)` that retrieves
#' `SPI_index.csv` — pillar-level and overall SPI index scores per
#' country-year in wide format.
#'
#' @inheritParams spi_get
#' @param country Character vector of ISO 3166-1 alpha-3 country codes (e.g.
#'   `c("NOR", "SWE")`). `NULL` returns all countries.
#'
#' @return A `data.table` in wide format with one row per country-year.
#'   Columns include `country`, `iso3c`, `date`, `SPI.INDEX`,
#'   `SPI.INDEX.PIL1`–`SPI.INDEX.PIL5`, dimension index columns, and
#'   individual indicator scores.
#'
#' @seealso [spi_data()], [spi_aggregates()], [spi_get()], [spi_versions()]
#'
#' @examples
#' \dontrun{
#' # All countries
#' spi_index()
#'
#' # High-income countries in 2024
#' spi_index(year = 2024)
#'
#' # Pillar 5 index and indicators for one country
#' spi_index(country = "KEN", pillar = 5)
#' }
#'
#' @export
spi_index <- function(version = "master",
                      country = NULL,
                      year = NULL,
                      pillar = NULL,
                      dimension = NULL) {
  spi_get(
    type      = "index",
    version   = version,
    country   = country,
    year      = year,
    pillar    = pillar,
    dimension = dimension
  )
}

#' Retrieve SPI regional aggregate scores
#'
#' A convenience wrapper around `spi_get("aggregates", ...)` that retrieves
#' `SPI_databank_country_and_aggregates.csv` filtered to regional aggregates
#' only (individual countries are excluded). The result is in long format
#' with one row per region-year-indicator.
#'
#' @inheritParams spi_get
#' @param region Character vector of region names (e.g.
#'   `"Africa Eastern and Southern"`). `NULL` returns all regions.
#'
#' @return A `data.table` in long format. Columns: `iso3c`, `country`
#'   (region name), `date`, `source_id`, `source_name`, `N`, `N_obs`,
#'   `value`, `footnote`.
#'
#' @seealso [spi_data()], [spi_index()], [spi_get()], [spi_versions()]
#'
#' @examples
#' \dontrun{
#' # All regions, all years
#' spi_aggregates()
#'
#' # One region, Pillar 1 indicators
#' spi_aggregates(region = "Africa Eastern and Southern", pillar = 1)
#'
#' # All regions, specific year range, specific dimension
#' spi_aggregates(year = 2020:2024, dimension = "5.2")
#' }
#'
#' @export
spi_aggregates <- function(version = "master",
                           region = NULL,
                           year = NULL,
                           pillar = NULL,
                           dimension = NULL) {
  spi_get(
    type      = "aggregates",
    version   = version,
    region    = region,
    year      = year,
    pillar    = pillar,
    dimension = dimension
  )
}
