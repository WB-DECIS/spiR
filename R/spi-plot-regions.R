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
#' Guide.
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
  .spi_plot_check_deps("ggplot2")

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
  region_dt <- region_dt[, .(region, date, value)]
  data.table::setorder(region_dt, region, date)

  scale_info <- .spi_plot_scale(region_dt$value)

  ggplot2::ggplot(
    region_dt,
    ggplot2::aes(x = date, y = value, color = region, group = region)
  ) +
    ggplot2::geom_line(linewidth = 1, lineend = "round", na.rm = FALSE) +
    ggplot2::geom_point(size = 1.8, na.rm = TRUE) +
    .spi_scale_color_wb_d(n = length(unique(region_dt$region))) +
    ggplot2::scale_y_continuous(limits = scale_info$limits) +
    ggplot2::labs(
      title = paste0(value_col, " by region over time"),
      x = NULL,
      y = "Score",
      color = NULL,
      caption = SPI_PLOT_CAPTION
    ) +
    .spi_theme_wb("line")
}
