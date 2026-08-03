# Internal World Bank visual style for spi_plot_* functions.
#
# These helpers reproduce the World Bank Data Visualization Style Guide
# (colours + theme) directly inside spiR, so the package does not depend on
# the external, non-CRAN {wbplot} package. Colours follow the official
# guide: https://worldbank.github.io/data-visualization-style-guide/colors

# Shared chart caption used by every spi_plot_* function.
SPI_PLOT_CAPTION <-
  "Source: World Bank Statistical Performance Indicators (SPI)"

# WB Data Viz Style Guide reference colours.
SPI_WB_TEXT <- "#111111"
SPI_WB_TEXT_SUBTLE <- "#666666"
SPI_WB_GRID <- "#EBEEF4"

# WB "Basic Category Colors" (cat1..cat5) used to distinguish series.
SPI_WB_CAT <- c(
  "#34A7F2", # cat1 blue
  "#FF9800", # cat2 orange
  "#664AB6", # cat3 purple
  "#4EC2C0", # cat4 teal
  "#F3578E"  # cat5 pink
)

# WB sequential palette (light -> dark blue) for continuous fills.
SPI_WB_SEQ <- c(
  "#EAF4FC", "#B8DCF7", "#7FC0F0", "#34A7F2", "#1F72AE", "#0A3D62"
)

#' Build a discrete World Bank colour vector of length `n`
#'
#' Returns the WB category colours directly when `n` fits, and interpolates
#' additional WB-derived colours otherwise.
#'
#' @param n Integer. Number of colours required.
#' @return Character vector of `n` hex colours.
#' @keywords internal
.spi_wb_pal_d <- function(n = length(SPI_WB_CAT)) {
  if (n <= length(SPI_WB_CAT)) {
    return(SPI_WB_CAT[seq_len(n)])
  }
  grDevices::colorRampPalette(SPI_WB_CAT)(n)
}

#' Discrete WB colour scale (replacement for wbplot::scale_color_wb_d)
#'
#' @param ... Passed to [ggplot2::scale_colour_manual()].
#' @return A ggplot2 scale.
#' @keywords internal
.spi_scale_color_wb_d <- function(...) {
  ggplot2::scale_colour_manual(values = .spi_wb_pal_d(12L), ...)
}

#' Discrete WB fill scale (replacement for wbplot::scale_fill_wb_d)
#'
#' @param ... Passed to [ggplot2::scale_fill_manual()].
#' @return A ggplot2 scale.
#' @keywords internal
.spi_scale_fill_wb_d <- function(...) {
  ggplot2::scale_fill_manual(values = .spi_wb_pal_d(12L), ...)
}

#' Continuous WB sequential fill scale (replacement for wbplot::scale_fill_wb_c)
#'
#' @param na.value Colour used for missing values.
#' @param ... Passed to [ggplot2::scale_fill_gradientn()].
#' @return A ggplot2 scale.
#' @keywords internal
.spi_scale_fill_wb_c <- function(na.value = "#CED4DE", ...) {
  ggplot2::scale_fill_gradientn(
    colours = SPI_WB_SEQ,
    na.value = na.value,
    ...
  )
}

#' World Bank plot theme (replacement for wbplot::theme_wb)
#'
#' @param chart_type Either `"line"` (default) or `"map"`.
#' @return A ggplot2 theme.
#' @keywords internal
.spi_theme_wb <- function(chart_type = c("line", "map")) {
  chart_type <- match.arg(chart_type)

  base <- ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(
        face = "bold", colour = SPI_WB_TEXT, size = 14
      ),
      plot.caption = ggplot2::element_text(
        colour = SPI_WB_TEXT_SUBTLE, size = 8, hjust = 0
      ),
      axis.title = ggplot2::element_text(colour = SPI_WB_TEXT_SUBTLE),
      axis.text = ggplot2::element_text(colour = SPI_WB_TEXT_SUBTLE),
      legend.position = "bottom",
      legend.text = ggplot2::element_text(colour = SPI_WB_TEXT),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(colour = SPI_WB_GRID)
    )

  if (chart_type == "map") {
    base <- base + ggplot2::theme(
      axis.title = ggplot2::element_blank(),
      axis.text = ggplot2::element_blank(),
      axis.ticks = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank(),
      legend.position = "right"
    )
  }

  base
}
