# Region-level trend comparison.

# Official geographic regions represented in the SPI aggregate data. Other
# aggregate rows, such as income groups and World Bank lending groups, are
# intentionally excluded from this visualization.
SPI_PLOT_GEOGRAPHIC_REGIONS <- c(
  "East Asia & Pacific",
  "Europe & Central Asia",
  "Latin America & Caribbean",
  "Middle East & North Africa",
  "North America",
  "South Asia",
  "Sub-Saharan Africa"
)

#' Compare a SPI column across official SPI regional aggregates over time
#'
#' Plots a single SPI column over time with one line per official SPI
#' regional aggregate, styled with the World Bank Data Visualization Style
#' Guide. The title uses metadata-derived SPI names and endpoint labels show
#' regional aggregate codes.
#'
#' @param regions Optional character vector of official geographic region
#'   names. `NULL` (default) plots the seven main geographic regions. Income
#'   groups and other World Bank aggregates are not supported.
#' @param value_col Character scalar. SPI column to plot. Defaults to
#'   `"SPI.INDEX"`.
#' @param version Character. SPI branch. Defaults to `"master"`.
#'
#' @return A [ggplot2::ggplot] object.
#'
#' @seealso [spi_plot_trend()], [spi_plot_region_pillars()]
#'
#' @examples
#' \dontrun{
#' spi_plot_regions()
#' spi_plot_regions(value_col = "SPI.INDEX.PIL3")
#' }
#'
#' @export
spi_plot_regions <- function(regions = NULL,
                             value_col = "SPI.INDEX",
                             version = "master") {
  .spi_plot_check_deps(c("ggplot2", "ggrepel"))

  if (!is.character(value_col) ||
      length(value_col) != 1L ||
      is.na(value_col) ||
      !nzchar(trimws(value_col))) {
    cli::cli_abort(
      "{.arg value_col} must be a single non-empty character string."
    )
  }
  value_col <- trimws(value_col)

  if (is.null(regions)) {
    regions <- SPI_PLOT_GEOGRAPHIC_REGIONS
  } else {
    if (!is.character(regions) || anyNA(regions)) {
      cli::cli_abort(
        "{.arg regions} must be a character vector with no NA values."
      )
    }

    regions <- unique(trimws(regions))
    if (length(regions) == 0L || any(!nzchar(regions))) {
      cli::cli_abort("{.arg regions} must contain at least one region name.")
    }
    unsupported <- setdiff(regions, SPI_PLOT_GEOGRAPHIC_REGIONS)
    if (length(unsupported) > 0L) {
      cli::cli_abort(c(
        "Only the seven main geographic regions are supported.",
        "x" = "Unsupported values: {.val {unsupported}}.",
        "i" = "Income groups and other World Bank aggregates are not regions."
      ))
    }
  }

  region_dt <- .spi_plot_fetch_aggregates(
    value_cols = value_col,
    version = version,
    region = regions
  )
  if (!"region_code" %in% names(region_dt)) {
    region_dt[, region_code := region]
  }
  region_dt <- region_dt[, .(region, region_code, date, value)]
  data.table::setorder(region_dt, region, date)

  axis_scale <- .spi_plot_scale_x_year(region_dt)
  latest <- .spi_plot_latest_points(
    dt = region_dt,
    series_col = "region",
    code_col = "region_code"
  )
  display_label <- .spi_plot_display_label(value_col = value_col, version = version)

  ggplot2::ggplot(
    region_dt,
    ggplot2::aes(x = date, y = value, color = region, group = region)
  ) +
    ggplot2::geom_line(linewidth = 1, lineend = "round", na.rm = FALSE) +
    ggplot2::geom_point(size = 1.8, na.rm = TRUE) +
    ggrepel::geom_text_repel(
      data = latest,
      ggplot2::aes(label = region_code),
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
      title = paste0(display_label, " by region over time"),
      x = NULL,
      y = "Score",
      color = NULL,
      caption = SPI_PLOT_CAPTION
    ) +
    .spi_theme_wb("line") +
    ggplot2::theme(plot.margin = ggplot2::margin(5.5, 25, 5.5, 5.5))
}
