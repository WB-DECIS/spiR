# Country vs region trend comparison.

#' Plot a country against its official regional aggregate over time
#'
#' Plots a single SPI column over time comparing one country against its
#' official regional SPI aggregate, styled with the World Bank Data
#' Visualization Style Guide. The title uses metadata-derived SPI names and
#' endpoint labels show the country ISO3 code and regional aggregate code.
#'
#' @param country Character scalar with a country name or ISO3 code.
#' @param value_col Character scalar. SPI column to plot. Defaults to
#'   `"SPI.INDEX.PIL1"`.
#' @param version Character. SPI branch. Defaults to `"master"`.
#'
#' @return A [ggplot2::ggplot] object.
#'
#' @seealso [spi_plot_trend()], [spi_plot_radar()], [spi_plot_regions()]
#'
#' @examples
#' \dontrun{
#' spi_plot_country_vs_region("Chile")
#' spi_plot_country_vs_region("KEN", value_col = "SPI.INDEX")
#' }
#'
#' @export
spi_plot_country_vs_region <- function(country,
                                       value_col = "SPI.INDEX.PIL1",
                                       version = "master") {
  .spi_plot_check_deps(c("ggplot2", "ggrepel"))

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

  region_avg <- .spi_plot_fetch_aggregates(
    value_cols = value_col,
    version = version,
    region = region_name
  )
  if (!"region_code" %in% names(region_avg)) {
    region_avg[, region_code := region]
  }
  region_avg <- region_avg[, .(date, value, series_code = region_code)]
  region_avg[, series := paste0(region_name, " (aggregate)")]

  selected_label <- selected_country[, unique(country_label)][1]
  selected_code <- selected_country[, unique(iso3c)][1]
  selected_country <- selected_country[, .(date, value)]
  selected_country[, series_code := selected_code]
  selected_country[, series := selected_label]

  plot_dt <- rbind(selected_country, region_avg, use.names = TRUE, fill = TRUE)
  data.table::setorder(plot_dt, series, date)

  axis_scale <- .spi_plot_scale_x_year(plot_dt)
  latest <- .spi_plot_latest_points(
    dt = plot_dt,
    series_col = "series",
    code_col = "series_code"
  )
  display_label <- .spi_plot_display_label(value_col = value_col, version = version)

  ggplot2::ggplot(plot_dt, ggplot2::aes(x = date, y = value, color = series)) +
    ggplot2::geom_line(linewidth = 1, lineend = "round", na.rm = FALSE) +
    ggplot2::geom_point(size = 1.8, na.rm = TRUE) +
    ggrepel::geom_text_repel(
      data = latest,
      ggplot2::aes(label = series_code),
      direction = "y",
      nudge_x = 0.25,
      hjust = 0,
      size = 3,
      segment.color = SPI_WB_GRID,
      show.legend = FALSE,
      na.rm = TRUE,
      max.overlaps = Inf
    ) +
    .spi_scale_color_wb_d() +
    axis_scale +
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::labs(
      title = paste0(display_label, " over time"),
      x = NULL,
      y = "Score",
      color = NULL,
      caption = SPI_PLOT_CAPTION
    ) +
    .spi_theme_wb("line") +
    ggplot2::theme(plot.margin = ggplot2::margin(5.5, 25, 5.5, 5.5))
}
