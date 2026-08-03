# Region pillar trajectories.

#' Plot official region pillar trajectories over time
#'
#' Plots the five SPI pillar trajectories over time for one official SPI
#' regional aggregate, styled with the World Bank Data Visualization Style
#' Guide. Values come from the official SPI regional aggregates so they match
#' published figures exactly.
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
  .spi_plot_check_deps("ggplot2")

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
  summary_dt <- summary_dt[, .(pillar = source_id, date, value)]

  data.table::setorder(summary_dt, pillar, date)

  ggplot2::ggplot(
    summary_dt,
    ggplot2::aes(x = date, y = value, color = pillar, group = pillar)
  ) +
    ggplot2::geom_line(linewidth = 1, lineend = "round", na.rm = FALSE) +
    ggplot2::geom_point(size = 1.8, na.rm = TRUE) +
    .spi_scale_color_wb_d() +
    ggplot2::scale_y_continuous(limits = c(0, 100)) +
    ggplot2::labs(
      title = paste0("SPI pillars over time: ", region),
      x = NULL,
      y = "Score",
      color = NULL,
      caption = SPI_PLOT_CAPTION
    ) +
    .spi_theme_wb("line")
}
