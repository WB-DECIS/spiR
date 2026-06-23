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
  dt <- spi_get(
    type      = "data",
    version   = version,
    country   = country,
    year      = year,
    pillar    = pillar,
    dimension = dimension
  )

  indicator_cols <- names(dt)[grepl("^SPI\\.D[0-9]|^RAW\\.D[0-9]", names(dt))]
  keep_cols <- unique(c("iso3c", "date", "country", indicator_cols))
  keep_cols <- keep_cols[keep_cols %in% names(dt)]

  dt[, keep_cols, with = FALSE]
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
  dt <- spi_get(
    type      = "index",
    version   = version,
    country   = country,
    year      = year,
    pillar    = pillar,
    dimension = dimension
  )

  payload_cols <- names(dt)[
    grepl("^SPI\\.INDEX|^SPI\\.DIM|^SPI\\.D[0-9]|^RAW\\.D[0-9]", names(dt))
  ]
  keep_cols <- unique(c("iso3c", "date", "country", payload_cols))
  keep_cols <- keep_cols[keep_cols %in% names(dt)]

  dt[, keep_cols, with = FALSE]
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
  dt <- spi_get(
    type      = "aggregates",
    version   = version,
    region    = region,
    year      = year,
    pillar    = pillar,
    dimension = dimension
  )

  keep_cols <- c("iso3c", "date", "country", "source_id", "value")
  keep_cols <- keep_cols[keep_cols %in% names(dt)]

  dt[, keep_cols, with = FALSE]
}



#' Retrieve specific SPI indicator columns
#'
#' A convenience wrapper around `spi_get("data", ...)` that returns only
#' requested SPI indicator columns from `SPI_data.csv`.
#'
#' @param indicator Character vector of SPI indicator column names,
#'   e.g. `"SPI.D1.5.POV"`.
#' @param version Character. Branch name in the SPI repository. Defaults
#'   to `"master"`.
#' @param country Character vector of ISO 3166-1 alpha-3 country codes.
#'   `NULL` returns all countries.
#' @param year Numeric or integer vector of years. `NULL` returns all years.
#' @param include_raw Logical scalar. If `TRUE`, also returns corresponding
#'   `RAW.D...` columns for the requested indicators when available.
#'
#' @return A `data.table` containing identifier/metadata columns plus the
#'   requested `SPI.D...` indicator columns (and optional raw columns).
#' @seealso [spi_data()], [spi_get()], [spi_versions()]
#' @examples
#' \dontrun{
#' spi_indicator("SPI.D1.5.POV", country = "CHL", year = 2024)
#' spi_indicator(c("SPI.D1.5.POV", "SPI.D2.1.GDDS"), include_raw = TRUE)
#' }
#' @export
spi_indicator <- function(indicator,
                          version = "master",
                          country = NULL,
                          year = NULL,
                          include_raw = FALSE) {
  if (!is.character(indicator) || anyNA(indicator) || length(indicator) == 0L) {
    cli::cli_abort(c(
      "{.arg indicator} must be a non-empty character vector with no NA values.",
      "x" = "You supplied a {.cls {class(indicator)[1L]}} of length {length(indicator)}."
    ))
  }

  if (!is.logical(include_raw) || length(include_raw) != 1L || is.na(include_raw)) {
    cli::cli_abort(c(
      "{.arg include_raw} must be a single logical value.",
      "x" = "You supplied {.val {include_raw}}."
    ))
  }

  indicator <- toupper(trimws(indicator))
  invalid <- indicator[!grepl("^SPI\\.D[0-9]+\\.[0-9]+\\.[A-Z0-9_.]+$", indicator)]
  if (length(invalid) > 0L) {
    cli::cli_abort(c(
      "{.arg indicator} must contain valid SPI indicator column names like {.val SPI.D1.5.POV}.",
      "x" = "Invalid names: {.field {invalid}}."
    ))
  }

  dt <- spi_get(
    type      = "data",
    version   = version,
    country   = country,
    year      = year,
    pillar    = NULL,
    dimension = NULL
  )

  missing <- setdiff(indicator, names(dt))
  if (length(missing) > 0L) {
    cli::cli_abort(c(
      "Requested indicator columns are not available in the downloaded SPI data.",
      "x" = "Missing columns: {.field {missing}}.",
      "i" = "Use {.fn spi_data()} to inspect available indicator names or check {.arg version}."
    ))
  }

  keep_cols <- c("iso3c", "date", "country", indicator)
  if (include_raw) {
    raw_cols <- paste0("RAW.", sub("^SPI\\.", "", indicator))
    raw_cols <- raw_cols[raw_cols %in% names(dt)]
    keep_cols <- c(keep_cols, raw_cols)
  }
  keep_cols <- unique(keep_cols)

  dt[, keep_cols, with = FALSE]
}
