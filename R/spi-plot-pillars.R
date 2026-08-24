# Pillar time-series plots for a single country.

#' Plot SPI pillar trajectories over time for one country
#'
#' Draws one line per SPI pillar across all available years for a single
#' country, styled with the World Bank Data Visualization Style Guide.
#' Pillar legend labels are metadata-derived names, while endpoint labels
#' show SPI pillar source codes.
#'
#' @param country Character scalar with a country name or ISO3 code.
#' @param pillars Character vector of pillar index columns. Defaults to the
#'   five SPI pillars (`SPI.INDEX.PIL1`--`SPI.INDEX.PIL5`).
#' @param version Character. SPI branch. Defaults to `"master"`.
#'
#' @return A [ggplot2::ggplot] object.
#'
#' @seealso [spi_plot_trend()], [spi_plot_radar()],
#'   [spi_plot_region_pillars()]
#'
#' @examples
#' \dontrun{
#' spi_plot_pillars("Chile")
#' spi_plot_pillars("KEN", pillars = c("SPI.INDEX.PIL1", "SPI.INDEX.PIL3"))
#' }
#'
#' @export
spi_plot_pillars <- function(country,
                             pillars = paste0("SPI.INDEX.PIL", 1:5),
                             version = "master") {
  .spi_plot_check_deps(c("ggplot2", "ggrepel"))

  if (!is.character(country) || length(country) != 1L || is.na(country)) {
    cli::cli_abort("{.arg country} must be a single character value.")
  }
  if (!is.character(pillars) || length(pillars) == 0L || anyNA(pillars)) {
    cli::cli_abort("{.arg pillars} must be a non-empty character vector.")
  }

  dt <- spi_index(version = version)
  need <- unique(c("country", "iso3c", "date", pillars))
  missing <- setdiff(need, names(dt))
  if (length(missing) > 0L) {
    cli::cli_abort(c(
      "Requested pillar columns are not available in SPI index data.",
      "x" = "Missing columns: {.field {missing}}."
    ))
  }

  key <- trimws(country)
  key_upper <- toupper(key)

  filtered <- dt[toupper(iso3c) == key_upper | trimws(country) == key]
  if (nrow(filtered) == 0L) {
    cli::cli_abort(c(
      "No rows found for requested country.",
      "x" = "Country input: {.val {country}}"
    ))
  }

  long <- data.table::melt(
    data = filtered[, need, with = FALSE],
    id.vars = c("country", "iso3c", "date"),
    measure.vars = pillars,
    variable.name = "pillar",
    value.name = "value"
  )
  long[, value := suppressWarnings(as.numeric(value))]
  long[, value := data.table::fifelse(value == -99, NA_real_, value)]
  long[, pillar_code := as.character(pillar)]
  pillar_labels <- .spi_plot_display_labels(pillars, version = version)
  long[, pillar_label := unname(pillar_labels[pillar_code])]
  data.table::setorder(long, pillar, date)

  selected_name <- unique(long$country)[1]
  axis_scale <- .spi_plot_scale_x_year(long)
  latest <- .spi_plot_latest_points(
    dt = long,
    series_col = "pillar_code",
    code_col = "pillar_code"
  )

  ggplot2::ggplot(
    long,
    ggplot2::aes(x = date, y = value, color = pillar_label, group = pillar_code)
  ) +
    ggplot2::geom_line(linewidth = 1, lineend = "round", na.rm = FALSE) +
    ggplot2::geom_point(size = 1.8, na.rm = TRUE) +
    ggrepel::geom_text_repel(
      data = latest,
      ggplot2::aes(label = pillar_code),
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
      title = paste0("SPI pillars over time: ", selected_name),
      x = NULL,
      y = "Score",
      color = NULL,
      caption = SPI_PLOT_CAPTION
    ) +
    .spi_theme_wb("line") +
    ggplot2::theme(plot.margin = ggplot2::margin(5.5, 25, 5.5, 5.5))
}
