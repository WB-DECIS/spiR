# Multi-country trend comparison.

#' Compare any SPI column over time across countries
#'
#' @param countries Character vector of country names or ISO3 codes.
#' @param value_col Character SPI column name.
#' @param version Character SPI branch.
#' @return A ggplot object.
#' @export
spi_plot_trend <- function(countries,
                           value_col = "SPI.INDEX",
                           version = "master") {
  .spi_plot_check_deps(c("ggplot2", "wbplot"))

  if (!is.character(countries) || length(countries) == 0L || anyNA(countries)) {
    cli::cli_abort("{.arg countries} must be a non-empty character vector.")
  }

  dt <- .spi_plot_fetch(value_col = value_col, version = version)
  dt[, country_label := ifelse(is.na(country), iso3c, country)]

  keys <- unique(trimws(countries))
  keys_upper <- toupper(keys)

  dt <- dt[toupper(iso3c) %in% keys_upper | country_label %in% keys]
  if (nrow(dt) == 0L) {
    cli::cli_abort(c(
      "No rows found for requested countries.",
      "x" = "Countries input: {.val {countries}}"
    ))
  }

  selected <- unique(dt$country_label)
  if (length(selected) < length(keys)) {
    missing <- setdiff(keys, selected)
    if (length(missing) > 0L) {
      cli::cli_warn(c(
        "Some requested countries were not found and were skipped.",
        "i" = "Skipped values: {.val {missing}}"
      ))
    }
  }

  scale_info <- .spi_plot_scale(dt$value)
  data.table::setorder(dt, country_label, date)

  ggplot2::ggplot(
    dt,
    ggplot2::aes(x = date, y = value, color = country_label, group = country_label)
  ) +
    ggplot2::geom_line(linewidth = 1, lineend = "round", na.rm = FALSE) +
    ggplot2::geom_point(size = 1.8, na.rm = TRUE) +
    wbplot::scale_color_wb_d() +
    ggplot2::scale_y_continuous(limits = scale_info$limits) +
    ggplot2::labs(
      title = paste0(value_col, " over time"),
      x = NULL,
      y = "Score",
      color = NULL,
      caption = "Source: World Bank Statistical Performance Indicators (SPI)"
    ) +
    wbplot::theme_wb(chartType = "line")
}
