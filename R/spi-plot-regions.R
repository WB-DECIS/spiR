# Region-level trend comparison.

#' Compare a SPI column across regions over time
#'
#' @param regions Optional character vector of region names.
#' @param value_col Character SPI column name.
#' @param version Character SPI branch.
#' @return A ggplot object.
#' @export
spi_plot_regions <- function(regions = NULL,
                             value_col = "SPI.INDEX",
                             version = "master") {
  .spi_plot_check_deps(c("ggplot2", "wbplot"))

  dt <- .spi_plot_fetch(value_col = value_col, version = version)
  dt <- .spi_plot_join_meta(dt, version = version, cols = "region")

  dt <- dt[!is.na(region) & nzchar(region)]
  if (!is.null(regions)) {
    if (!is.character(regions) || length(regions) == 0L || anyNA(regions)) {
      cli::cli_abort("{.arg regions} must be a non-empty character vector with no NA values.")
    }
    dt <- dt[region %in% regions]
  }

  if (nrow(dt) == 0L) {
    cli::cli_abort("No rows available for requested region filters.")
  }

  region_dt <- dt[, .(value = mean(value, na.rm = TRUE)), by = .(region, date)]
  region_dt[is.nan(value), value := NA_real_]
  data.table::setorder(region_dt, region, date)

  scale_info <- .spi_plot_scale(region_dt$value)

  ggplot2::ggplot(
    region_dt,
    ggplot2::aes(x = date, y = value, color = region, group = region)
  ) +
    ggplot2::geom_line(linewidth = 1, lineend = "round", na.rm = FALSE) +
    ggplot2::geom_point(size = 1.8, na.rm = TRUE) +
    wbplot::scale_color_wb_d() +
    ggplot2::scale_y_continuous(limits = scale_info$limits) +
    ggplot2::labs(
      title = paste0(value_col, " by region over time"),
      x = NULL,
      y = "Score",
      color = NULL,
      caption = "Source: World Bank Statistical Performance Indicators (SPI)"
    ) +
    wbplot::theme_wb(chartType = "line")
}
