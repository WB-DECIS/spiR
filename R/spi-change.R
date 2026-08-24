#' Add changes from the previous and first valid data years
#'
#' Calculates within-group score changes without assuming that every calendar
#' year is present. Missing scores do not become observations, and repeated
#' rows for a group-year receive the same change values.
#'
#' @param data A data.frame or data.table containing SPI scores.
#' @param value_col Character scalar naming the score column. Defaults to
#'   `"SPI.INDEX"`.
#' @param group_cols Character vector naming columns that identify a series.
#'   Defaults to `"iso3c"`.
#' @param year_col Character scalar naming the year column. Defaults to
#'   `"date"`.
#' @return A data.table with the input columns and `change_previous` and
#'   `change_first` columns. The input object is not modified.
#' @seealso [spi_index()], [spi_plot_trend()]
#' @examples
#' \dontrun{
#' scores <- spi_index(country = "KEN")
#' spi_change(scores)
#' }
#' @export
spi_change <- function(data,
                       value_col = "SPI.INDEX",
                       group_cols = "iso3c",
                       year_col = "date") {
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data.frame or data.table.")
  }
  if (!is.character(value_col) || length(value_col) != 1L ||
      is.na(value_col) || !nzchar(trimws(value_col))) {
    cli::cli_abort("{.arg value_col} must be a single non-empty string.")
  }
  if (!is.character(year_col) || length(year_col) != 1L ||
      is.na(year_col) || !nzchar(trimws(year_col))) {
    cli::cli_abort("{.arg year_col} must be a single non-empty string.")
  }
  if (!is.character(group_cols) || length(group_cols) == 0L ||
      anyNA(group_cols) || any(!nzchar(trimws(group_cols)))) {
    cli::cli_abort("{.arg group_cols} must be a non-empty character vector.")
  }

  value_col <- trimws(value_col)
  year_col <- trimws(year_col)
  group_cols <- trimws(group_cols)
  required <- unique(c(value_col, year_col, group_cols))
  missing <- setdiff(required, names(data))
  if (length(missing) > 0L) {
    cli::cli_abort(c(
      "SPI change data is missing required columns.",
      "x" = "Missing: {.field {missing}}."
    ))
  }

  result <- data.table::as.data.table(data.table::copy(data))
  row_id <- ".spi_change_row_id"
  while (row_id %in% names(result)) {
    row_id <- paste0(row_id, "_")
  }
  result[, (row_id) := seq_len(.N)]
  years <- suppressWarnings(as.integer(result[[year_col]]))
  values <- suppressWarnings(as.numeric(result[[value_col]]))
  result[, `:=`(.spi_change_year = years, .spi_change_value = values)]

  duplicate_values <- result[!is.na(.spi_change_year) &
    !is.na(.spi_change_value),
    .(n_values = data.table::uniqueN(.spi_change_value)),
    by = c(group_cols, ".spi_change_year")][n_values > 1L]
  if (nrow(duplicate_values) > 0L) {
    cli::cli_abort(c(
      "SPI change data has conflicting values for the same group-year.",
      "x" = "Each combination of {.field {group_cols}} and {.field {year_col}} must have one score.",
      "i" = "Resolve duplicate group-year rows before calling {.fn spi_change}."
    ))
  }

  changes <- result[, {
    valid <- which(!is.na(.spi_change_year) & !is.na(.spi_change_value))
    previous <- rep(NA_real_, .N)
    first <- rep(NA_real_, .N)
    if (length(valid) > 0L) {
      ordered <- valid[order(.spi_change_year[valid], valid)]
      first_value <- .spi_change_value[ordered[[1L]]]
      first[valid] <- .spi_change_value[valid] - first_value
      for (row_number in valid) {
        prior <- ordered[
          .spi_change_year[ordered] < .spi_change_year[[row_number]]
        ]
        if (length(prior) > 0L) {
          previous_row <- prior[[length(prior)]]
          previous[[row_number]] <-
            .spi_change_value[[row_number]] -
            .spi_change_value[[previous_row]]
        }
      }
    }
    data.table::data.table(
      row_id = get(row_id),
      change_previous = previous,
      change_first = first
    )
  }, by = group_cols]

  data.table::setnames(changes, "row_id", row_id)
  result[changes, on = row_id, `:=`(
    change_previous = i.change_previous,
    change_first = i.change_first
  )]
  result[, c(".spi_change_year", ".spi_change_value", row_id) := NULL]
  result[]
}