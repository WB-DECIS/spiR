# Shared internal helpers for spi_plot_* functions.

#' Validate optional visualization dependencies
#'
#' @param pkgs Character vector of package names.
#' @return Invisible NULL. Aborts if one or more packages are unavailable.
#' @keywords internal
.spi_plot_check_deps <- function(pkgs) {
  if (!is.character(pkgs) || length(pkgs) == 0L || anyNA(pkgs)) {
    cli::cli_abort(
      "{.arg pkgs} must be a non-empty character vector with no NA values."
    )
  }

  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1L), quietly = TRUE)]
  if (length(missing) > 0L) {
    cli::cli_abort(c(
      "Required visualization packages are not installed.",
      "x" = "Missing packages: {.val {missing}}.",
      "i" = "Install them and retry this plotting function."
    ))
  }

  invisible(NULL)
}


#' Fetch a single SPI value column in tidy plotting format
#'
#' Routes to [spi_index()] for index/dimension columns and to [spi_data()]
#' for indicator columns, then returns a normalized table with one `value`
#' column and standardized identifiers.
#'
#' @param value_col Character scalar with exact SPI column name.
#' @param version Character scalar SPI branch.
#' @param country Optional ISO3 vector.
#' @param year Optional integer/numeric year vector.
#' @return A `data.table` with columns `iso3c`, `date`, `country`, `value`.
#' @keywords internal
.spi_plot_fetch <- function(value_col,
                            version = "master",
                            country = NULL,
                            year = NULL) {
  if (!is.character(value_col) || length(value_col) != 1L || is.na(value_col)) {
    cli::cli_abort("{.arg value_col} must be a single non-empty character string.")
  }

  value_col <- trimws(value_col)
  if (!nzchar(value_col)) {
    cli::cli_abort("{.arg value_col} must be a single non-empty character string.")
  }

  use_index <- grepl("^SPI\\.(INDEX|DIM)", value_col)

  src <- if (use_index) {
    spi_index(version = version, country = country, year = year)
  } else {
    spi_data(version = version, country = country, year = year)
  }

  if (!value_col %in% names(src)) {
    available <- names(src)[grepl("^(SPI\\.|RAW\\.)", names(src))]
    preview <- if (length(available) > 40L) available[1:40] else available
    cli::cli_abort(c(
      "Requested SPI column was not found in downloaded data.",
      "x" = "Column {.val {value_col}} is unavailable.",
      "i" = "Available SPI/RAW columns include: {.val {preview}}"
    ))
  }

  if (!"iso3c" %in% names(src) || !"date" %in% names(src)) {
    cli::cli_abort(c(
      "Downloaded source is missing required identifier columns.",
      "x" = "Expected columns {.field iso3c} and {.field date}."
    ))
  }

  out <- data.table::data.table(
    iso3c = toupper(trimws(as.character(src[["iso3c"]]))),
    date = as.integer(src[["date"]]),
    country = if ("country" %in% names(src)) as.character(src[["country"]]) else NA_character_,
    value = suppressWarnings(as.numeric(src[[value_col]]))
  )

  out[, value := data.table::fifelse(value == -99, NA_real_, value)]

  if (!is.null(year)) {
    keep_year <- as.integer(year)
    out <- out[date %in% keep_year]
  }

  out <- out[!is.na(iso3c) & nchar(iso3c) == 3L]

  if (nrow(out) == 0L) {
    cli::cli_abort(c(
      "No rows available after applying plotting filters.",
      "i" = "Check {.arg year}, {.arg country}, or {.arg value_col}."
    ))
  }

  data.table::setorder(out, iso3c, date)
  return(out)
}


#' Fetch official SPI aggregate rows for plotting
#'
#' Retrieves one or more `source_id` series from [spi_aggregates()] and
#' normalizes them for plotting regional aggregate lines or profiles.
#'
#' @param value_cols Character vector of exact SPI aggregate `source_id`
#'   values.
#' @param version Character scalar SPI branch.
#' @param region Optional character vector of aggregate names.
#' @param year Optional integer/numeric year vector.
#' @return A `data.table` with columns `region`, `date`, `source_id`, `value`.
#' @keywords internal
.spi_plot_fetch_aggregates <- function(value_cols,
                                       version = "master",
                                       region = NULL,
                                       year = NULL) {
  if (!is.character(value_cols) || length(value_cols) == 0L || anyNA(value_cols)) {
    cli::cli_abort(
      "{.arg value_cols} must be a non-empty character vector with no NA values."
    )
  }

  value_cols <- trimws(value_cols)
  if (any(!nzchar(value_cols))) {
    cli::cli_abort(
      "{.arg value_cols} must contain only non-empty SPI source identifiers."
    )
  }
  if (any(grepl("^RAW\\.", value_cols))) {
    unsupported <- value_cols[grepl("^RAW\\.", value_cols)]
    cli::cli_abort(c(
      "RAW columns are not available in {.fn spi_aggregates}.",
      "x" = "Unsupported source ids: {.val {unsupported}}."
    ))
  }

  src <- spi_aggregates(version = version, region = region, year = year)
  if (!all(c("country", "date", "source_id", "value") %in% names(src))) {
    cli::cli_abort(c(
      "Aggregate source is missing required columns.",
      "x" = "Expected columns {.field country}, {.field date}, {.field source_id}, and {.field value}."
    ))
  }

  out <- src[source_id %in% value_cols, .(
    region = as.character(country),
    date = as.integer(date),
    source_id = as.character(source_id),
    value = suppressWarnings(as.numeric(value))
  )]
  out[, value := data.table::fifelse(value == -99, NA_real_, value)]

  found <- unique(out[["source_id"]])
  missing <- setdiff(value_cols, found)
  if (length(missing) > 0L) {
    available <- unique(as.character(src[["source_id"]]))
    preview <- if (length(available) > 40L) available[1:40] else available
    cli::cli_abort(c(
      "Requested SPI aggregate series were not found.",
      "x" = "Missing aggregate source ids: {.val {missing}}.",
      "i" = "Available aggregate source ids include: {.val {preview}}"
    ))
  }

  if (nrow(out) == 0L) {
    cli::cli_abort(c(
      "No aggregate rows available after applying plotting filters.",
      "i" = "Check {.arg region}, {.arg year}, or {.arg value_cols}."
    ))
  }

  data.table::setorder(out, region, source_id, date)
  return(out)
}


#' Detect SPI plotting scale from observed values
#'
#' @param values Numeric vector.
#' @return Named list with entries `limits`, `digits`, and `is_share`.
#' @keywords internal
.spi_plot_scale <- function(values) {
  num <- suppressWarnings(as.numeric(values))
  num <- num[is.finite(num)]

  if (length(num) == 0L) {
    return(list(limits = c(0, 100), digits = 1L, is_share = FALSE))
  }

  is_share <- max(num, na.rm = TRUE) <= 1
  if (is_share) {
    return(list(limits = c(0, 1), digits = 3L, is_share = TRUE))
  }

  list(limits = c(0, 100), digits = 1L, is_share = FALSE)
}


#' Join plotting table with country metadata columns
#'
#' @param dt A plotting `data.table` with `iso3c` and `date` columns.
#' @param version Character SPI branch.
#' @param cols Character vector of metadata columns to attach.
#' @return A `data.table` with requested metadata columns merged in.
#' @keywords internal
.spi_plot_join_meta <- function(dt,
                                version = "master",
                                cols = c("region", "population")) {
  if (!data.table::is.data.table(dt)) {
    cli::cli_abort("{.arg dt} must be a {.cls data.table}.")
  }
  if (!all(c("iso3c", "date") %in% names(dt))) {
    cli::cli_abort(c(
      "{.arg dt} is missing required key columns.",
      "x" = "Required: {.field iso3c}, {.field date}."
    ))
  }
  if (!is.character(cols) || length(cols) == 0L || anyNA(cols)) {
    cli::cli_abort("{.arg cols} must be a non-empty character vector with no NA values.")
  }

  meta <- country_info(
    version = version,
    country = unique(dt[["iso3c"]]),
    year = unique(dt[["date"]])
  )

  required <- unique(c("iso3c", "date", cols))
  missing <- setdiff(required, names(meta))
  if (length(missing) > 0L) {
    cli::cli_abort(c(
      "Missing metadata columns from {.fn country_info} output.",
      "x" = "Missing metadata: {.field {missing}}."
    ))
  }

  meta_small <- meta[, required, with = FALSE]
  out <- merge(dt, meta_small, by = c("iso3c", "date"), all.x = TRUE, sort = FALSE)

  out
}
