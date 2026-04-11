# Core data access functions for the spiR package.

# ---------------------------------------------------------------------------
# File path map for the three output datasets
# ---------------------------------------------------------------------------
SPI_FILE_PATHS <- list(
  data       = "03_output_data/SPI_data.csv",
  index      = "03_output_data/SPI_index.csv",
  aggregates = "03_output_data/SPI_databank_country_and_aggregates.csv"
)

# Required columns that must be present in every downloaded SPI file
SPI_REQUIRED_COLS <- c("iso3c", "date")

# ---------------------------------------------------------------------------
# spi_get() — main retrieval function
# ---------------------------------------------------------------------------

#' Retrieve SPI output data from GitHub
#'
#' Downloads one of the three core SPI output datasets from the
#' [World Bank SPI GitHub repository](https://github.com/worldbank/SPI) and
#' optionally filters the result. For a more focused API, see the
#' convenience wrappers [spi_data()], [spi_index()], and
#' [spi_aggregates()].
#'
#' @param type Character. Which dataset to retrieve:
#'   * `"data"` — `SPI_data.csv`: individual indicator scores per
#'     country-year (wide format).
#'   * `"index"` — `SPI_index.csv`: pillar and overall SPI index scores
#'     per country-year (wide format).
#'   * `"aggregates"` — regional aggregate scores (long format, regions
#'     only — individual countries are excluded).
#' @param version Character. Branch name in the SPI repository. Defaults to
#'   `"master"` (the latest stable version). Use [spi_versions()] to list
#'   available branches.
#' @param country Character vector of ISO 3166-1 alpha-3 country codes (e.g.
#'   `c("NOR", "SWE")`). Applies to `type = "data"` and `type = "index"`
#'   only. `NULL` returns all countries.
#' @param year Integer vector of years (e.g. `2023:2024`). Applies to all
#'   types. `NULL` returns all years.
#' @param pillar Integer (1-5). Restricts indicator columns to the specified
#'   SPI pillar. For `"data"` and `"index"`: column subsetting. For
#'   `"aggregates"`: row filtering on `source_id`. `NULL` returns all
#'   pillars. Ignored when `dimension` is also supplied.
#' @param dimension Character in `"P.D"` format (e.g. `"5.2"`, `"1.5"`).
#'   Restricts to a specific dimension. More specific than `pillar`; when
#'   both are supplied, `dimension` takes precedence. `NULL` returns all
#'   dimensions.
#' @param region Character vector of region names (e.g.
#'   `"Africa Eastern and Southern"`). Applies to `type = "aggregates"`
#'   only. `NULL` returns all regions.
#'
#' @return A `data.table`. For `"data"` and `"index"`: wide format with
#'   one row per country-year. For `"aggregates"`: long format with one row
#'   per region-year-indicator.
#'
#' @seealso [spi_data()], [spi_index()], [spi_aggregates()],
#'   [spi_versions()]
#'
#' @examples
#' \dontrun{
#' # Full SPI data for all countries
#' spi_get("data")
#'
#' # Norway and Sweden, year 2024, Pillar 3 columns only
#' spi_get("data", country = c("NOR", "SWE"), year = 2024, pillar = 3)
#'
#' # SPI index, dimension 5.2 only
#' spi_get("index", dimension = "5.2")
#'
#' # Regional aggregates for Africa, Pillar 1
#' spi_get("aggregates",
#'   region = "Africa Eastern and Southern",
#'   pillar = 1
#' )
#'
#' # Use a specific version (branch)
#' spi_get("data", version = "SPI2023")
#' }
#'
#' @export
spi_get <- function(type = "data",
                    version = "master",
                    country = NULL,
                    year = NULL,
                    pillar = NULL,
                    dimension = NULL,
                    region = NULL) {
  type <- match.arg(type, c("data", "index", "aggregates"))

  # --- Input validation ---------------------------------------------------

  if (!is.character(version) || length(version) != 1L || !nzchar(version)) {
    cli::cli_abort(c(
      "{.arg version} must be a single non-empty character string.",
      "x" = "You supplied a {.cls {class(version)[1L]}}."
    ))
  }

  if (!is.null(country)) {
    if (!is.character(country) || anyNA(country))
      cli::cli_abort(c(
        "{.arg country} must be a character vector with no NA values.",
        "x" = "You supplied a {.cls {class(country)[1L]}}."
      ))
  }

  if (!is.null(region)) {
    if (!is.character(region) || anyNA(region))
      cli::cli_abort(c(
        "{.arg region} must be a character vector with no NA values.",
        "x" = "You supplied a {.cls {class(region)[1L]}}."
      ))
  }

  if (!is.null(country) && type == "aggregates") {
    cli::cli_abort(c(
      "Cannot use {.arg country} with {.code type = \"aggregates\"}.",
      "i" = "Use {.arg region} to filter aggregate data by region."
    ))
  }

  if (!is.null(region) && type %in% c("data", "index")) {
    cli::cli_abort(c(
      "Cannot use {.arg region} with {.code type = \"{type}\"}.",
      "i" = "Use {.arg country} to filter data/index by country."
    ))
  }

  if (!is.null(year)) {
    if ((!is.numeric(year) && !is.integer(year)) || anyNA(year))
      cli::cli_abort(c(
        "{.arg year} must be a numeric or integer vector with no NA values.",
        "x" = "You supplied a {.cls {class(year)[1L]}}."
      ))
  }

  if (!is.null(pillar)) {
    if (!is.numeric(pillar) || length(pillar) != 1L ||
        is.na(pillar) || !pillar %in% 1:5) {
      cli::cli_abort(c(
        "{.arg pillar} must be a single integer between 1 and 5.",
        "x" = "You supplied {.val {pillar}}."
      ))
    }
    pillar <- as.integer(pillar)
  }

  if (!is.null(dimension)) {
    if (!is.character(dimension) || length(dimension) != 1L ||
        is.na(dimension) ||
        !grepl("^[0-9]+\\.[0-9]+$", dimension)) {
      cli::cli_abort(c(
        "{.arg dimension} must be a string in {.val P.D} format (e.g. {.val 5.2} or {.val 1.5}).",
        "x" = "You supplied {.val {dimension}}."
      ))
    }
  }

  # --- Download -----------------------------------------------------------

  dt <- spi_download(SPI_FILE_PATHS[[type]], version = version)

  # --- Schema validation --------------------------------------------------

  missing_cols <- setdiff(SPI_REQUIRED_COLS, names(dt))
  if (length(missing_cols) > 0L) {
    cli::cli_abort(c(
      "Downloaded file is missing expected columns.",
      "x" = "Missing: {.field {missing_cols}}.",
      "i" = "Check that {.arg version} = {.val {version}} points to a valid SPI release."
    ))
  }

  # --- Filter -------------------------------------------------------------

  if (type %in% c("data", "index")) {
    if (!is.null(country)) {
      keep <- dt[["iso3c"]] %in% country
      dt <- dt[keep]
    }
    if (!is.null(year)) {
      keep <- dt[["date"]] %in% year
      dt <- dt[keep]
    }
    # Column filtering: dimension takes precedence over pillar
    if (!is.null(dimension)) {
      dt <- filter_columns_by_dimension(dt, dimension)
    } else if (!is.null(pillar)) {
      dt <- filter_columns_by_pillar(dt, pillar)
    }
  } else {
    # aggregates: keep only region rows (no individual countries)
    keep <- is_aggregate_code(dt[["iso3c"]])
    dt <- dt[keep]

    if (!is.null(region)) {
      keep <- dt[["country"]] %in% region
      dt <- dt[keep]
    }
    if (!is.null(year)) {
      keep <- dt[["date"]] %in% year
      dt <- dt[keep]
    }
    dt <- filter_rows_by_pillar_dimension(dt, pillar, dimension)
  }

  return(dt)
}
