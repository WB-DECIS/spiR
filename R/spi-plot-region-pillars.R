# Region pillar trajectories.

#' Plot official region pillar trajectories over time
#'
#' Plots the five SPI pillar trajectories over time for one official SPI
#' regional aggregate, styled with the World Bank Data Visualization Style
#' Guide. Values come from the official SPI regional aggregates so they match
#' published figures exactly. Pillar legend labels use metadata-derived names
#' while endpoint labels show SPI pillar source codes.
#'
#' @param region Character scalar with a WB region name.
#' @param weighted Logical scalar. Must be `TRUE`; regional plots use the
#'   official SPI aggregates so they match published values exactly.
#' @param pillars Character vector of pillar index columns. Defaults to the
#'   five SPI pillars.
#' @param version Character. SPI branch. Defaults to `"master"`.
#'
#' @return A [ggplot2::ggplot] object.
#'
#' @seealso [spi_plot_regions()], [spi_plot_pillars()]
#'
#' @examples
#' \dontrun{
#' spi_plot_region_pillars("Latin America & Caribbean")
#' }
#'
#' @export
spi_plot_region_pillars <- function(region,
                                    weighted = TRUE,
                                    pillars = paste0("SPI.INDEX.PIL", 1:5),
                                    version = "master") {
  .spi_plot_check_deps(c("ggplot2", "ggrepel"))

  if (!is.character(region) || length(region) != 1L || is.na(region)) {
    cli::cli_abort("{.arg region} must be a single character value.")
  }
  if (!is.logical(weighted) || length(weighted) != 1L || is.na(weighted)) {
    cli::cli_abort("{.arg weighted} must be a single logical value.")
  }
  if (!isTRUE(weighted)) {
    cli::cli_abort(c(
      "Unweighted regional pillar plots are not supported.",
      "i" = "This function now uses official SPI regional aggregates to match published values exactly.",
      "i" = "Call {.fn spi_plot_region_pillars} with {.code weighted = TRUE}."
    ))
  }
  if (!is.character(pillars) || length(pillars) == 0L || anyNA(pillars)) {
    cli::cli_abort("{.arg pillars} must be a non-empty character vector.")
  }

  region_input <- trimws(region)
  summary_dt <- .spi_plot_fetch_aggregates(
    value_cols = pillars,
    version = version,
    region = region_input
  )
  summary_dt <- summary_dt[, .(pillar_code = source_id, date, value)]
  pillar_labels <- .spi_plot_display_labels(pillars, version = version)
  summary_dt[, pillar_label := unname(pillar_labels[pillar_code])]

  data.table::setorder(summary_dt, pillar_code, date)
  axis_scale <- .spi_plot_scale_x_year(summary_dt)
  latest <- .spi_plot_latest_points(
    dt = summary_dt,
    series_col = "pillar_code",
    code_col = "pillar_code"
  )

  ggplot2::ggplot(
    summary_dt,
    ggplot2::aes(
      x = date,
      y = value,
      color = pillar_label,
      group = pillar_code
    )
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
      title = paste0("SPI pillars over time: ", region_input),
      x = NULL,
      y = "Score",
      color = NULL,
      caption = SPI_PLOT_CAPTION
    ) +
    .spi_theme_wb("line") +
    ggplot2::theme(plot.margin = ggplot2::margin(5.5, 25, 5.5, 5.5))
}
