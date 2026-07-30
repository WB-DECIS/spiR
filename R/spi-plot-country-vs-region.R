# Country vs region trend comparison.

#' Plot a country against its regional average over time
#'
#' @param country Character scalar with country name or ISO3 code.
#' @param value_col Character SPI column name.
#' @param version Character SPI branch.
#' @return A ggplot object.
#' @export
spi_plot_country_vs_region <- function(country,
                                       value_col = "SPI.INDEX.PIL1",
                                       version = "master") {
  .spi_plot_check_deps(c("ggplot2", "wbplot"))

  if (!is.character(country) || length(country) != 1L || is.na(country)) {
    cli::cli_abort("{.arg country} must be a single character value.")
  }

  dt <- .spi_plot_fetch(value_col = value_col, version = version)
  dt <- .spi_plot_join_meta(dt, version = version, cols = "region")
  dt[, country_label := ifelse(is.na(country), iso3c, country)]

  key <- trimws(country)
  key_upper <- toupper(key)

  selected_country <- dt[toupper(iso3c) == key_upper | country_label == key]
  if (nrow(selected_country) == 0L) {
    cli::cli_abort(c(
      "No rows found for requested country.",
      "x" = "Country input: {.val {country}}"
    ))
  }

  region_name <- selected_country[!is.na(region), unique(region)][1]
  if (is.na(region_name) || !nzchar(region_name)) {
    cli::cli_abort("Could not determine region for requested country.")
  }

  region_avg <- dt[region == region_name, .(
    value = mean(value, na.rm = TRUE)
  ), by = .(date)]
  region_avg[is.nan(value), value := NA_real_]
  region_avg[, series := paste0(region_name, " (avg.)")]

  selected_country <- selected_country[, .(date, value)]
  selected_country[, series := unique(country_label)[1]]

  plot_dt <- rbind(selected_country, region_avg, use.names = TRUE, fill = TRUE)
  data.table::setorder(plot_dt, series, date)

  scale_info <- .spi_plot_scale(plot_dt$value)

  ggplot2::ggplot(plot_dt, ggplot2::aes(x = date, y = value, color = series)) +
    ggplot2::geom_line(linewidth = 1, lineend = "round", na.rm = FALSE) +
    ggplot2::geom_point(size = 1.8, na.rm = TRUE) +
    wbplot::scale_color_wb_d() +
    ggplot2::scale_y_continuous(limits = scale_info$limits) +
    ggplot2::labs(
      title = value_col,
      x = NULL,
      y = "Score",
      color = NULL,
      caption = "Source: World Bank Statistical Performance Indicators (SPI)"
    ) +
    wbplot::theme_wb(chartType = "line")
}
