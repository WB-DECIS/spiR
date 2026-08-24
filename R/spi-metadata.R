# Created: 2026-08-04
# Metadata accessors and metadata-specific helpers for the spiR package.


# Metadata source path in the SPI repository.
SPI_METADATA_PATH <- "01_raw_data/metadata/SPI_full_metadata.csv"

# Required metadata columns expected in SPI full metadata.
SPI_METADATA_REQUIRED_COLS <- c(
  "pillar", "pillar_name", "pillar_description", "pillar_id",
  "dimension", "dimension_name", "dimension_description", "dimension_id",
  "indicator", "indicator_name", "indicator_description", "indicator_id",
  "indicator_scoring", "indicator_abv"
)

# Normalize and validate metadata headers and required columns.
.spi_validate_metadata_schema <- function(dt, version) {
  old_names <- names(dt)
  new_names <- tolower(trimws(old_names))
  new_names <- gsub("[^a-z0-9]+", "_", new_names)
  new_names <- gsub("_+", "_", new_names)
  new_names <- gsub("^_|_$", "", new_names)

  if (anyDuplicated(new_names)) {
    dupes <- unique(new_names[duplicated(new_names)])
    cli::cli_abort(c(
      "Downloaded SPI metadata has ambiguous column names after normalization.",
      "x" = "Duplicated normalized columns: {.field {dupes}}.",
      "i" = "Version: {version}",
      "i" = "Path: {SPI_METADATA_PATH}"
    ))
  }

  data.table::setnames(dt, old = old_names, new = new_names)

  missing_cols <- setdiff(SPI_METADATA_REQUIRED_COLS, names(dt))
  if (length(missing_cols) > 0L) {
    cli::cli_abort(c(
      "Downloaded SPI metadata is missing required metadata columns.",
      "x" = "Missing columns: {.field {missing_cols}}.",
      "i" = "Version: {version}",
      "i" = "Path: {SPI_METADATA_PATH}"
    ))
  }

  dt
}

#' Read and validate SPI metadata from GitHub
#'
#' Internal helper used by metadata accessors. Downloads
#' `SPI_full_metadata.csv`, validates required schema, and normalizes join keys
#' to character.
#'
#' @param version Character. Branch name in SPI repository.
#' @return A validated `data.table` with metadata rows.
#' @keywords internal
.spi_read_metadata <- function(version = "master") {
  .spi_validate_version(version)

  dt <- tryCatch(
    spi_download(SPI_METADATA_PATH, version = version),
    error = function(e) {
      cli::cli_abort(c(
        "Failed to retrieve SPI metadata.",
        "x" = "Caused by: {conditionMessage(e)}",
        "i" = "Version: {version}",
        "i" = "Path: {SPI_METADATA_PATH}"
      ), parent = e)
    }
  )

  dt <- .spi_validate_metadata_schema(dt, version)

  # Normalize key columns and preserve the canonical package-facing forms.
  dt[, pillar := trimws(as.character(pillar))]
  dt[, pillar_id := trimws(as.character(pillar_id))]
  dt[, dimension := trimws(as.character(dimension))]
  dt[, dimension_id := trimws(as.character(dimension_id))]
  dt[, indicator := trimws(as.character(indicator))]
  dt[, indicator_id := trimws(as.character(indicator_id))]

  # Upstream stores dimension as the within-pillar sequence (e.g. "1") while
  # the package API uses the canonical P.D form (e.g. "2.1").
  dt[
    !grepl("^[0-9]+\\.[0-9]+$", dimension),
    dimension := paste0(pillar, ".", dimension)
  ]

  # Use the SPI code as the canonical indicator identifier exposed by the API.
  dt[
    !grepl("^SPI\\.", indicator) & nzchar(indicator_id),
    indicator := indicator_id
  ]

  return(dt)
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

# Validate accepted metadata filter formats.
.metadata_validate_filter_format <- function(pillar_filter, dimension_filter) {
  if (!is.null(pillar_filter) &&
      !grepl("^[0-9]+$|^SPI\\.INDEX\\.PIL[0-9]+$", pillar_filter)) {
    cli::cli_abort(c(
      "{.arg pillar} must be a canonical pillar value or SPI pillar ID.",
      "x" = "You supplied {.val {pillar_filter}}.",
      "i" = "Examples: {.val 1}, {.val SPI.INDEX.PIL1}"
    ))
  }

  if (!is.null(dimension_filter) &&
      !grepl("^[0-9]+\\.[0-9]+$|^SPI\\.DIM[0-9]+\\.[0-9]+\\.INDEX$",
             dimension_filter)) {
    cli::cli_abort(c(
      "{.arg dimension} must be a canonical dimension value or SPI dimension ID.",
      "x" = "You supplied {.val {dimension_filter}}.",
      "i" = "Examples: {.val 2.1}, {.val SPI.DIM2.1.INDEX}"
    ))
  }
}


# Resolve a metadata filter against either the canonical value or the SPI ID.
.metadata_resolve_filter <- function(md,
                                     value,
                                     canonical_col,
                                     id_col,
                                     arg_name,
                                     version,
                                     allow_no_match = FALSE) {
  if (is.null(value)) return(NULL)

  matches <- md[
    md[[canonical_col]] == value |
      md[[id_col]] == value
  ]

  if (nrow(matches) == 0L) {
    if (allow_no_match) {
      return(value)
    }

    details <- NULL

    if (arg_name == "pillar") {
      details <- c(
        "i" = "Accepted formats: canonical pillar (e.g. {.val 1}) or SPI pillar ID (e.g. {.val SPI.INDEX.PIL1}).",
        "i" = "Valid canonical values: {.field {sort(unique(md[[canonical_col]]))}}."
      )
    }

    if (arg_name == "dimension") {
      details <- c(
        "i" = "Accepted formats: canonical dimension (e.g. {.val 1.1}) or SPI dimension ID (e.g. {.val SPI.DIM1.1.INDEX}).",
        "i" = "Valid canonical values include: {.field {utils::head(sort(unique(md[[canonical_col]])), 10L)}}."
      )
    }

    cli::cli_abort(c(
      "{.arg {arg_name}} is not available in this metadata version.",
      "x" = "You supplied {.val {value}}.",
      "i" = "Version: {.val {version}}.",
      details
    ))
  }

  unique(matches[[canonical_col]])
}

# Validate hierarchy consistency after filters are resolved.
.metadata_validate_hierarchy_consistency <- function(md,
                                                     pillar_filter,
                                                     dimension_filter,
                                                     indicator_filter) {
  if (!is.null(pillar_filter) && !is.null(dimension_filter)) {
    dim_pillar <- sub("\\..*$", "", dimension_filter)
    if (!identical(dim_pillar, pillar_filter)) {
      cli::cli_abort(c(
        "Supplied filters are hierarchically inconsistent.",
        "x" = paste0(
          "Dimension {.val ", dimension_filter,
          "} belongs to pillar {.val ", dim_pillar,
          "}, not {.val ", pillar_filter, "}."
        )
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
}

# Ensure each hierarchy key maps to one descriptive payload.
.metadata_assert_unique_payload <- function(dt,
                                            key_cols,
                                            value_cols,
                                            key_label) {
  if (nrow(dt) == 0L) {
    return(invisible(NULL))
  }

  check_dt <- dt[, lapply(.SD, data.table::uniqueN),
                 by = key_cols, .SDcols = value_cols]

  bad <- check_dt[
    check_dt[, Reduce(`|`, lapply(.SD, function(x) x > 1L)),
             .SDcols = value_cols]
  ]

  if (nrow(bad) > 0L) {
    key_values <- do.call(paste, c(bad[, ..key_cols], sep = " / "))
    cli::cli_abort(c(
      "SPI metadata has conflicting hierarchy text for the same key.",
      "x" = "Conflicting {.val {key_label}} keys: {.field {key_values}}."
    ))
  }

  invisible(NULL)
}


#' Retrieve SPI metadata hierarchy
#'
#' Downloads SPI metadata and returns a standardized list with pillar,
#' dimension, and indicator tables. Optional filters can be supplied as strings
#' and must be hierarchically consistent.
#'
#' @param pillar Character scalar pillar filter. Accepts either the canonical
#'   pillar value (e.g. `"1"`) or the SPI pillar ID (e.g.
#'   `"SPI.INDEX.PIL1"`). `NULL` means no pillar filter.
#' @param dimension Character scalar dimension filter. Accepts either the
#'   canonical `"P.D"` form (e.g. `"2.1"`) or the SPI dimension ID (e.g.
#'   `"SPI.DIM2.1.INDEX"`). `NULL` means no dimension filter.
#' @param indicator Character scalar indicator filter. Accepts the canonical
#'   SPI indicator code (e.g. `"SPI.D1.5.POV"`). `NULL` means no indicator
#'   filter.
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
#' metadata(pillar = "SPI.INDEX.PIL1")
#' metadata(dimension = "2.1")
#' metadata(dimension = "SPI.DIM2.1.INDEX")
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

  .metadata_validate_filter_format(pillar_filter, dimension_filter)

  md <- .spi_read_metadata(version = version)

  pillar_filter <- .metadata_resolve_filter(
    md = md,
    value = pillar_filter,
    canonical_col = "pillar",
    id_col = "pillar_id",
    arg_name = "pillar",
    version = version
  )

  dimension_filter <- .metadata_resolve_filter(
    md = md,
    value = dimension_filter,
    canonical_col = "dimension",
    id_col = "dimension_id",
    arg_name = "dimension",
    version = version
  )

  indicator_filter <- .metadata_resolve_filter(
    md = md,
    value = indicator_filter,
    canonical_col = "indicator",
    id_col = "indicator_id",
    arg_name = "indicator",
    version = version,
    allow_no_match = TRUE
  )

  .metadata_validate_hierarchy_consistency(
    md = md,
    pillar_filter = pillar_filter,
    dimension_filter = dimension_filter,
    indicator_filter = indicator_filter
  )

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

  .metadata_assert_unique_payload(
    dt = filtered,
    key_cols = "pillar",
    value_cols = c("pillar_name", "pillar_description", "pillar_id"),
    key_label = "pillar"
  )

  pillars <- filtered[, .(
    pillar_name = pillar_name[1L],
    pillar_description = pillar_description[1L],
    pillar_id = pillar_id[1L]
  ), by = .(pillar)]
  if (nrow(pillars) > 0L) {
    pillars <- pillars[order(as.integer(pillar), pillar)]
  }

  .metadata_assert_unique_payload(
    dt = filtered,
    key_cols = c("pillar", "dimension"),
    value_cols = c("dimension_name", "dimension_description", "dimension_id"),
    key_label = "dimension"
  )

  dimensions <- filtered[, .(
    dimension_name = dimension_name[1L],
    dimension_description = dimension_description[1L],
    dimension_id = dimension_id[1L]
  ), by = .(pillar, dimension)]
  if (nrow(dimensions) > 0L) {
    dimensions <- dimensions[order(as.integer(pillar), dimension)]
  }

  indicator_rows <- filtered[
    !is.na(indicator) & nzchar(indicator)
  ]

  .metadata_assert_unique_payload(
    dt = indicator_rows,
    key_cols = c("pillar", "dimension", "indicator"),
    value_cols = c(
      "indicator_name", "indicator_description", "indicator_id",
      "indicator_scoring", "indicator_abv"
    ),
    key_label = "indicator"
  )

  indicators <- indicator_rows[, .(
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
#' @param pillar Character scalar pillar filter. Accepts either the canonical
#'   pillar value (e.g. `"2"`) or the SPI pillar ID (e.g.
#'   `"SPI.INDEX.PIL2"`), or `NULL`.
#' @param version Character. Branch name in SPI repository. Defaults to
#'   `"master"`.
#'
#' @return A `data.table` with dimension-level metadata.
#' @seealso [metadata()], [metadata_pillars()]
#' @examples
#' \dontrun{
#' metadata_dimensions()
#' metadata_dimensions(pillar = "2")
#' metadata_dimensions(pillar = "SPI.INDEX.PIL2")
#' }
#' @export
metadata_dimensions <- function(pillar = NULL, version = "master") {
  metadata(pillar = pillar, version = version)[["dimensions"]]
}


#' Retrieve SPI indicator metadata
#'
#' Convenience wrapper that returns the indicator block from [metadata()].
#'
#' @param pillar Character scalar pillar filter. Accepts either the canonical
#'   pillar value (e.g. `"2"`) or the SPI pillar ID (e.g.
#'   `"SPI.INDEX.PIL2"`), or `NULL`.
#' @param dimension Character scalar dimension filter. Accepts either the
#'   canonical `"P.D"` form (e.g. `"2.1"`) or the SPI dimension ID (e.g.
#'   `"SPI.DIM2.1.INDEX"`), or `NULL`.
#' @param indicator Character scalar indicator filter. Accepts the canonical
#'   SPI indicator code (e.g. `"SPI.D1.5.POV"`), or `NULL`.
#' @param version Character. Branch name in SPI repository. Defaults to
#'   `"master"`.
#'
#' @return A `data.table` with indicator-level metadata. This function returns
#'   metadata definitions (names, descriptions, scoring, IDs), not country-year
#'   indicator values; for data values see [spi_indicator()].
#' @seealso [metadata()], [metadata_pillars()], [metadata_dimensions()],
#'   [spi_indicator()]
#' @examples
#' \dontrun{
#' metadata_indicators()
#' metadata_indicators(pillar = "2")
#' metadata_indicators(dimension = "2.1")
#' metadata_indicators(indicator = "SPI.D2.1.GDDS")
#' }
#' @export
metadata_indicators <- function(pillar = NULL,
                                dimension = NULL,
                                indicator = NULL,
                                version = "master") {
  metadata(
    pillar = pillar,
    dimension = dimension,
    indicator = indicator,
    version = version
  )[["indicators"]]
}
