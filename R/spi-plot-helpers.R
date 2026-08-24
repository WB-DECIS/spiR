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
    if ((!is.numeric(year) && !is.integer(year)) || anyNA(year) ||
        any(year != floor(year))) {
      cli::cli_abort("{.arg year} must contain only integer-valued years.")
    }
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
    region_code = toupper(trimws(as.character(iso3c))),
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
  if (anyDuplicated(meta_small, by = c("iso3c", "date")) > 0L) {
    cli::cli_abort(c(
      "Country metadata has duplicate country-year keys.",
      "x" = "Metadata must contain one row per {.field iso3c}/{.field date} combination."
    ))
  }
  out <- merge(dt, meta_small, by = c("iso3c", "date"), all.x = TRUE, sort = FALSE)

  out
}


#' Round a year down to the previous five-year boundary
#'
#' @param year Integer or numeric scalar year.
#' @return Integer year rounded down to a multiple of five.
#' @keywords internal
.spi_plot_floor_year_to_five <- function(year) {
  if ((!is.numeric(year) && !is.integer(year)) || length(year) != 1L || is.na(year)) {
    cli::cli_abort("{.arg year} must be a single numeric/integer year.")
  }

  as.integer(floor(as.numeric(year) / 5) * 5)
}


#' Build time-axis specification for SPI charts
#'
#' @param dt A plotting `data.table`.
#' @param year_col Name of the year column.
#' @param value_col Name of the value column.
#' @param right_padding Numeric padding added to the right x limit.
#' @return Named list with `start_year`, `end_year`, `breaks`, and `limits`.
#' @keywords internal
.spi_plot_time_axis_spec <- function(dt,
                                     year_col = "date",
                                     value_col = "value",
                                     right_padding = 0.8) {
  if (!data.table::is.data.table(dt)) {
    cli::cli_abort("{.arg dt} must be a {.cls data.table}.")
  }
  missing_cols <- setdiff(c(year_col, value_col), names(dt))
  if (length(missing_cols) > 0L) {
    cli::cli_abort(c(
      "Missing required plotting columns.",
      "x" = "Missing columns: {.field {missing_cols}}."
    ))
  }

  year_values <- suppressWarnings(as.integer(dt[[year_col]]))
  if (all(is.na(year_values))) {
    cli::cli_abort(c(
      "No valid year values available for plotting.",
      "x" = "Column {.field {year_col}} contains only missing or invalid values."
    ))
  }

  value_num <- suppressWarnings(as.numeric(dt[[value_col]]))
  valid_idx <- !is.na(year_values) & !is.na(value_num) & is.finite(value_num)

  first_year <- if (any(valid_idx)) {
    min(year_values[valid_idx], na.rm = TRUE)
  } else {
    min(year_values, na.rm = TRUE)
  }

  end_year <- max(year_values, na.rm = TRUE)
  start_year <- .spi_plot_floor_year_to_five(first_year)
  if (end_year < start_year) {
    end_year <- start_year
  }

  breaks <- sort(unique(c(seq(start_year, end_year, by = 5L), end_year)))
  limits <- c(start_year, end_year + as.numeric(right_padding))

  list(
    start_year = as.integer(start_year),
    end_year = as.integer(end_year),
    breaks = as.integer(breaks),
    limits = as.numeric(limits)
  )
}


#' Build a shared x scale for year-based SPI charts
#'
#' @param dt A plotting `data.table`.
#' @param year_col Name of the year column.
#' @param value_col Name of the value column.
#' @return A `ggplot2::scale_x_continuous` object.
#' @keywords internal
.spi_plot_scale_x_year <- function(dt,
                                   year_col = "date",
                                   value_col = "value") {
  axis_spec <- .spi_plot_time_axis_spec(
    dt = dt,
    year_col = year_col,
    value_col = value_col
  )

  ggplot2::scale_x_continuous(
    breaks = axis_spec$breaks,
    limits = axis_spec$limits,
    expand = ggplot2::expansion(mult = c(0, 0))
  )
}


#' Select latest non-missing observation per series
#'
#' @param dt A plotting `data.table`.
#' @param series_col Name of the series column.
#' @param code_col Name of the stable code column for labels.
#' @param year_col Name of the year column.
#' @param value_col Name of the value column.
#' @return A `data.table` containing one latest row per eligible series.
#' @keywords internal
.spi_plot_latest_points <- function(dt,
                                    series_col,
                                    code_col,
                                    year_col = "date",
                                    value_col = "value") {
  if (!data.table::is.data.table(dt)) {
    cli::cli_abort("{.arg dt} must be a {.cls data.table}.")
  }
  need <- c(series_col, code_col, year_col, value_col)
  missing_cols <- setdiff(need, names(dt))
  if (length(missing_cols) > 0L) {
    cli::cli_abort(c(
      "Missing required columns for latest-value labels.",
      "x" = "Missing columns: {.field {missing_cols}}."
    ))
  }

  tmp <- data.table::copy(dt)
  tmp[, (year_col) := suppressWarnings(as.integer(get(year_col)))]
  tmp[, (value_col) := suppressWarnings(as.numeric(get(value_col)))]
  tmp <- tmp[!is.na(get(year_col)) & !is.na(get(value_col)) & is.finite(get(value_col))]

  if (nrow(tmp) == 0L) {
    return(tmp)
  }

  data.table::setorderv(tmp, c(series_col, year_col), c(1L, 1L))
  tmp[, .SD[.N], by = series_col]
}


#' Resolve human-readable display label for a SPI source code
#'
#' @param value_col Character scalar SPI code.
#' @param version Character SPI branch.
#' @return Character scalar display label.
#' @keywords internal
.spi_plot_display_label <- function(value_col, version = "master") {
  if (!is.character(value_col) || length(value_col) != 1L || is.na(value_col)) {
    cli::cli_abort("{.arg value_col} must be a single non-empty character string.")
  }

  value_col <- trimws(value_col)
  if (!nzchar(value_col)) {
    cli::cli_abort("{.arg value_col} must be a single non-empty character string.")
  }

  if (identical(value_col, "SPI.INDEX")) {
    return("SPI Index")
  }

  .prefix_label <- function(prefix, name_value) {
    name_value <- trimws(as.character(name_value))
    if (!nzchar(name_value)) {
      return(prefix)
    }
    if (startsWith(tolower(name_value), tolower(prefix))) {
      return(name_value)
    }
    paste0(prefix, name_value)
  }

  md <- metadata(version = version)

  pillar_match <- regexec("^SPI\\.INDEX\\.PIL([0-9]+)$", value_col)
  pillar_parts <- regmatches(value_col, pillar_match)[[1]]
  if (length(pillar_parts) == 2L) {
    pillar_num <- pillar_parts[2]
    pillars <- md[["pillars"]]
    if (!all(c("pillar", "pillar_name", "pillar_id") %in% names(pillars))) {
      cli::cli_abort("Pillar metadata is missing required fields for label resolution.")
    }
    hit <- pillars[pillar_id == value_col | pillar == pillar_num]
    if (nrow(hit) == 0L) {
      cli::cli_abort(c(
        "Could not resolve pillar label from metadata.",
        "x" = "Missing metadata for {.val {value_col}}."
      ))
    }
    return(.prefix_label(
      prefix = paste0("Pillar ", hit$pillar[1], ": "),
      name_value = hit$pillar_name[1]
    ))
  }

  dim_match <- regexec("^SPI\\.DIM([0-9]+\\.[0-9]+)\\.INDEX$", value_col)
  dim_parts <- regmatches(value_col, dim_match)[[1]]
  if (length(dim_parts) == 2L) {
    dim_code <- dim_parts[2]
    dims <- md[["dimensions"]]
    if (!all(c("dimension", "dimension_name", "dimension_id") %in% names(dims))) {
      cli::cli_abort("Dimension metadata is missing required fields for label resolution.")
    }
    hit <- dims[dimension_id == value_col | dimension == dim_code]
    if (nrow(hit) == 0L) {
      cli::cli_abort(c(
        "Could not resolve dimension label from metadata.",
        "x" = "Missing metadata for {.val {value_col}}."
      ))
    }
    return(.prefix_label(
      prefix = paste0("Dimension ", hit$dimension[1], ": "),
      name_value = hit$dimension_name[1]
    ))
  }

  indicators <- md[["indicators"]]
  if (!all(c("indicator_id", "indicator_name") %in% names(indicators))) {
    cli::cli_abort("Indicator metadata is missing required fields for label resolution.")
  }
  indicator_hit <- indicators[indicator_id == value_col]
  if (nrow(indicator_hit) > 0L) {
    return(.prefix_label(
      prefix = paste0("Indicator ", value_col, ": "),
      name_value = indicator_hit$indicator_name[1]
    ))
  }

  if (grepl("^SPI\\.", value_col)) {
    cli::cli_abort(c(
      "Could not resolve SPI label from metadata.",
      "x" = "No metadata entry for {.val {value_col}}."
    ))
  }

  value_col
}


#' Resolve display labels for multiple SPI source codes
#'
#' @param value_cols Character vector of SPI source codes.
#' @param version Character SPI branch.
#' @return Named character vector of display labels.
#' @keywords internal
.spi_plot_display_labels <- function(value_cols, version = "master") {
  if (!is.character(value_cols) || length(value_cols) == 0L || anyNA(value_cols)) {
    cli::cli_abort("{.arg value_cols} must be a non-empty character vector.")
  }

  labels <- vapply(
    value_cols,
    function(x) .spi_plot_display_label(x, version = version),
    FUN.VALUE = character(1L)
  )
  stats::setNames(labels, value_cols)
}
