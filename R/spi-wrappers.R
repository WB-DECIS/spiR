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

#' Retrieve SPI aggregate/group scores
#'
#' A convenience wrapper around `spi_get("aggregates", ...)` that retrieves
#' `SPI_databank_country_and_aggregates.csv` filtered to aggregate/group rows
#' only (individual countries are excluded). The result is in long format
#' with one row per aggregate-year-indicator.
#'
#' @inheritParams spi_get
#' @param region Character vector of region names (e.g.
#'   `"Africa Eastern and Southern"`). `NULL` returns all regions.
#'
#' @return A `data.table` in long format. Columns: `iso3c`, `date`,
#'   `country` (aggregate/group name), `source_id`, and `value`.
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


#' Retrieve SPI country-year metadata
#'
#' A convenience wrapper around `spi_get("data", ...)` that returns only
#' country metadata columns from `SPI_data.csv`. The result preserves one row
#' per country-year because metadata such as income level and population can
#' change over time.
#'
#' @param version Character. Branch name in the SPI repository. Defaults
#'   to `"master"`.
#' @param country Character vector of ISO 3166-1 alpha-3 country codes.
#'   `NULL` returns all countries.
#' @param year Numeric or integer vector of years. `NULL` returns all years.
#'
#' @return A `data.table` with one row per country-year and these columns,
#'   in order: `date`, `iso3c`, `iso2c`, `country`, `capital_city`,
#'   `longitude`, `latitude`, `region_iso3c`, `region_iso2c`, `region`,
#'   `admin_region_iso3c`, `admin_region_iso2c`, `admin_region`,
#'   `income_level_iso3c`, `income_level_iso2c`, `income_level`,
#'   `lending_type_iso3c`, `lending_type_iso2c`, `lending_type`, and
#'   `population`. Rows are returned in deterministic `iso3c`, `date` order.
#' @seealso [spi_data()], [spi_get()], [spi_versions()]
#' @examples
#' \dontrun{
#' country_info(country = "CHL", year = 2024)
#' country_info(year = 2020:2024)
#' }
#' @export
country_info <- function(version = "master",
                         country = NULL,
                         year = NULL) {
  dt <- spi_get(
    type      = "data",
    version   = version,
    country   = country,
    year      = year,
    pillar    = NULL,
    dimension = NULL
  )

  keep_cols <- c(
    "date", "iso3c", "iso2c", "country", "capital_city", "longitude",
    "latitude", "region_iso3c", "region_iso2c", "region",
    "admin_region_iso3c", "admin_region_iso2c", "admin_region",
    "income_level_iso3c", "income_level_iso2c", "income_level",
    "lending_type_iso3c", "lending_type_iso2c", "lending_type",
    "population"
  )

  missing <- setdiff(keep_cols, names(dt))
  if (length(missing) > 0L) {
    cli::cli_abort(c(
      "Downloaded SPI data is missing required country metadata columns.",
      "x" = "Missing columns: {.field {missing}}.",
      "i" = "Check that {.arg version} = {.val {version}} points to a valid SPI release."
    ))
  }

  result <- dt[, keep_cols, with = FALSE]
  result[order(result[["iso3c"]], result[["date"]])]
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


# Normalize and validate one metadata filter argument.
.metadata_normalize_arg <- function(value, arg_name) {
  if (is.null(value)) return(NULL)

  if (!is.character(value) || length(value) != 1L || is.na(value)) {
    cli::cli_abort(c(
      "{.arg {arg_name}} must be a single non-empty character string.",
      "x" = "You supplied a {.cls {class(value)[1L]}} of length {length(value)}."
    ))
  }

  value <- trimws(value)
  if (!nzchar(value)) {
    cli::cli_abort(c(
      "{.arg {arg_name}} must be a single non-empty character string.",
      "x" = "You supplied an empty value."
    ))
  }

  value
}


#' Retrieve SPI metadata hierarchy
#'
#' Downloads SPI metadata and returns a standardized list with pillar,
#' dimension, and indicator tables. Optional filters can be supplied as strings
#' and must be hierarchically consistent.
#'
#' @param pillar Character scalar, e.g. `"1"`. `NULL` means no pillar filter.
#' @param dimension Character scalar in `"P.D"` format (e.g. `"2.1"`).
#'   `NULL` means no dimension filter.
#' @param indicator Character scalar indicator code (e.g. `"SPI.D1.5.POV"`).
#'   `NULL` means no indicator filter.
#' @param version Character. Branch name in the SPI repository. Defaults to
#'   `"master"`.
#'
#' @return A named list with three `data.table` elements: `pillars`,
#'   `dimensions`, and `indicators`.
#' @seealso [metadata_pillars()], [metadata_dimensions()], [spi_data()],
#'   [spi_indicator()]
#' @examples
#' \dontrun{
#' metadata(pillar = "1")
#' metadata(dimension = "2.1")
#' metadata(indicator = "SPI.D1.5.POV")
#' }
#' @export
metadata <- function(pillar = NULL,
                     dimension = NULL,
                     indicator = NULL,
                     version = "master") {
  pillar <- .metadata_normalize_arg(pillar, "pillar")
  dimension <- .metadata_normalize_arg(dimension, "dimension")
  indicator <- .metadata_normalize_arg(indicator, "indicator")

  pillar_filter <- pillar
  dimension_filter <- dimension
  indicator_filter <- indicator

  if (!is.null(dimension_filter) &&
      !grepl("^[0-9]+\\.[0-9]+$", dimension_filter)) {
    cli::cli_abort(c(
      "{.arg dimension} must be a string in {.val P.D} format.",
      "x" = "You supplied {.val {dimension_filter}}.",
      "i" = "Example: {.val 2.1}"
    ))
  }

  md <- .spi_read_metadata(version = version)

  valid_pillars <- sort(unique(md[["pillar"]]))
  if (!is.null(pillar_filter) && !pillar_filter %in% valid_pillars) {
    cli::cli_abort(c(
      "{.arg pillar} is not available in this metadata version.",
      "x" = "You supplied {.val {pillar_filter}}.",
      "i" = "Valid values for version {.val {version}}: {.field {valid_pillars}}."
    ))
  }

  if (!is.null(pillar_filter) && !is.null(dimension_filter)) {
    dim_pillar <- sub("\\..*$", "", dimension_filter)
    if (!identical(dim_pillar, pillar_filter)) {
      cli::cli_abort(c(
        "Supplied filters are hierarchically inconsistent.",
        "x" = "Dimension {.val {dimension_filter}} belongs to pillar {.val {dim_pillar}}, not {.val {pillar_filter}}."
      ))
    }
  }

  indicator_rows <- NULL
  if (!is.null(indicator_filter)) {
    indicator_rows <- md[md[["indicator"]] == indicator_filter]
  }

  if (!is.null(pillar_filter) && !is.null(indicator_filter) &&
      !is.null(indicator_rows) && nrow(indicator_rows) > 0L) {
    if (!all(indicator_rows[["pillar"]] == pillar_filter)) {
      expected <- unique(indicator_rows[["pillar"]])
      cli::cli_abort(c(
        "Supplied filters are hierarchically inconsistent.",
        "x" = "Indicator {.val {indicator_filter}} belongs to pillar {.val {expected}}, not {.val {pillar_filter}}."
      ))
    }
  }

  if (!is.null(dimension_filter) && !is.null(indicator_filter) &&
      !is.null(indicator_rows) && nrow(indicator_rows) > 0L) {
    if (!all(indicator_rows[["dimension"]] == dimension_filter)) {
      expected <- unique(indicator_rows[["dimension"]])
      cli::cli_abort(c(
        "Supplied filters are hierarchically inconsistent.",
        "x" = "Indicator {.val {indicator_filter}} does not belong to dimension {.val {dimension_filter}}.",
        "i" = "Indicator belongs to: {.field {expected}}."
      ))
    }
  }

  filtered <- data.table::copy(md)

  if (!is.null(pillar_filter)) {
    filtered <- filtered[filtered[["pillar"]] == pillar_filter]
  }
  if (!is.null(dimension_filter)) {
    filtered <- filtered[filtered[["dimension"]] == dimension_filter]
  }
  if (!is.null(indicator_filter)) {
    filtered <- filtered[filtered[["indicator"]] == indicator_filter]
  }

  # Upstream metadata can include text variants for the same hierarchy key.
  # Always collapse by key to guarantee one row per pillar.
  pillars <- filtered[, .(
    pillar_name = pillar_name[1L],
    pillar_description = pillar_description[1L],
    pillar_id = pillar_id[1L]
  ), by = .(pillar)]
  if (nrow(pillars) > 0L) {
    pillars <- pillars[order(as.integer(pillar), pillar)]
  }

  dimensions <- filtered[, .(
    dimension_name = dimension_name[1L],
    dimension_description = dimension_description[1L],
    dimension_id = dimension_id[1L]
  ), by = .(pillar, dimension)]
  if (nrow(dimensions) > 0L) {
    dimensions <- dimensions[order(as.integer(pillar), dimension)]
  }

  indicators <- filtered[, .(
    indicator_name = indicator_name[1L],
    indicator_description = indicator_description[1L],
    indicator_id = indicator_id[1L],
    indicator_scoring = indicator_scoring[1L],
    indicator_abv = indicator_abv[1L]
  ), by = .(pillar, dimension, indicator)]
  if (nrow(indicators) > 0L) {
    indicators <- indicators[order(as.integer(pillar), dimension, indicator)]
  }

  if (nrow(indicators) == 0L) {
    cli::cli_warn(c(
      "No metadata rows matched the supplied filters.",
      "i" = "Version: {.val {version}}"
    ))
  }

  return(list(
    pillars = pillars,
    dimensions = dimensions,
    indicators = indicators
  ))
}


#' Retrieve SPI pillar metadata
#'
#' Convenience wrapper that returns the pillar block from [metadata()].
#'
#' @param version Character. Branch name in SPI repository. Defaults to
#'   `"master"`.
#'
#' @return A `data.table` with pillar-level metadata.
#' @seealso [metadata()], [metadata_dimensions()]
#' @examples
#' \dontrun{
#' metadata_pillars()
#' }
#' @export
metadata_pillars <- function(version = "master") {
  metadata(version = version)[["pillars"]]
}


#' Retrieve SPI dimension metadata
#'
#' Convenience wrapper that returns the dimension block from [metadata()].
#'
#' @param pillar Character scalar pillar filter (e.g. `"2"`), or `NULL`.
#' @param version Character. Branch name in SPI repository. Defaults to
#'   `"master"`.
#'
#' @return A `data.table` with dimension-level metadata.
#' @seealso [metadata()], [metadata_pillars()]
#' @examples
#' \dontrun{
#' metadata_dimensions()
#' metadata_dimensions(pillar = "2")
#' }
#' @export
metadata_dimensions <- function(pillar = NULL, version = "master") {
  metadata(pillar = pillar, version = version)[["dimensions"]]
}
