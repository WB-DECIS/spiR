# Pillar time-series plots for a single country.

#' Plot SPI pillar trajectories over time for one country
#'
#' Draws one line per SPI pillar across all available years for a single
#' country, styled with the World Bank Data Visualization Style Guide.
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
  .spi_plot_check_deps("ggplot2")

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
  data.table::setorder(long, pillar, date)

  selected_name <- unique(long$country)[1]

  ggplot2::ggplot(long, ggplot2::aes(x = date, y = value, color = pillar)) +
    ggplot2::geom_line(linewidth = 1, lineend = "round", na.rm = FALSE) +
    ggplot2::geom_point(size = 1.8, na.rm = TRUE) +
    .spi_scale_color_wb_d() +
    ggplot2::labs(
      title = paste0("SPI pillars over time: ", selected_name),
      x = NULL,
      y = "Score",
      color = NULL,
      caption = SPI_PLOT_CAPTION
    ) +
    .spi_theme_wb("line")
}
