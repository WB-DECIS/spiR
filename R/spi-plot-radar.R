# Radar chart for country pillar profile.

#' Radar coordinates with straight sides
#' @param theta Axis orientation.
#' @param start Start angle.
#' @param direction Direction sign.
#' @keywords internal
coord_radar <- function(theta = "x", start = 0, direction = 1) {
  theta <- match.arg(theta, c("x", "y"))
  r <- if (theta == "x") "y" else "x"

  ggplot2::ggproto(
    "CoordRadar",
    ggplot2::CoordPolar,
    theta = theta,
    r = r,
    start = start,
    direction = sign(direction),
    is_linear = function(coord) TRUE
  )
}

#' Radar chart of SPI pillars for one country vs official regional aggregate
#'
#' Draws a radar (spider) chart comparing a country's five SPI pillar scores
#' against its official regional SPI aggregate for a given year, styled with
#' the World Bank Data Visualization Style Guide.
#'
#' @param country Character scalar with a country name or ISO3 code.
#' @param year Integer year to display.
#' @param version Character. SPI branch. Defaults to `"master"`.
#'
#' @return A [ggplot2::ggplot] object.
#'
#' @seealso [spi_plot_pillars()], [spi_plot_country_vs_region()]
#'
#' @examples
#' \dontrun{
#' spi_plot_radar("Chile", year = 2023)
#' spi_plot_radar("KEN", year = 2022)
#' }
#'
#' @export
spi_plot_radar <- function(country,
                           year,
                           version = "master") {
  .spi_plot_check_deps("ggplot2")

  if (!is.character(country) || length(country) != 1L || is.na(country)) {
    cli::cli_abort("{.arg country} must be a single character value.")
  }
  if ((!is.numeric(year) && !is.integer(year)) || length(year) != 1L || is.na(year)) {
    cli::cli_abort("{.arg year} must be a single numeric/integer value.")
  }

  pillars <- paste0("SPI.INDEX.PIL", 1:5)
  dt <- spi_index(version = version)
  need <- unique(c("country", "iso3c", "date", pillars))
  missing <- setdiff(need, names(dt))
  if (length(missing) > 0L) {
    cli::cli_abort(c(
      "SPI index data is missing required pillar columns.",
      "x" = "Missing columns: {.field {missing}}."
    ))
  }

  dt <- dt[date == as.integer(year)]
  if (nrow(dt) == 0L) {
    cli::cli_abort("No rows found for requested {.arg year}.")
  }

  long <- data.table::melt(
    data = dt[, need, with = FALSE],
    id.vars = c("country", "iso3c", "date"),
    measure.vars = pillars,
    variable.name = "pillar",
    value.name = "value"
  )
  long[, value := suppressWarnings(as.numeric(value))]
  long[, value := data.table::fifelse(value == -99, NA_real_, value)]

  long <- .spi_plot_join_meta(long, version = version, cols = "region")
  long[, country_label := ifelse(is.na(country), iso3c, country)]

  key <- trimws(country)
  key_upper <- toupper(key)

  country_dt <- long[toupper(iso3c) == key_upper | country_label == key]
  if (nrow(country_dt) == 0L) {
    cli::cli_abort(c(
      "No rows found for requested country.",
      "x" = "Country input: {.val {country}}"
    ))
  }

  region_name <- country_dt[!is.na(region), unique(region)][1]
  if (is.na(region_name) || !nzchar(region_name)) {
    cli::cli_abort("Could not determine region for requested country.")
  }

  region_dt <- .spi_plot_fetch_aggregates(
    value_cols = pillars,
    version = version,
    region = region_name,
    year = as.integer(year)
  )
  region_dt <- region_dt[, .(pillar = source_id, value)]
  region_dt[, series := paste0(region_name, " (aggregate)")]

  selected_label <- country_dt[, unique(country_label)][1]
  country_dt <- country_dt[, .(pillar, value)]
  country_dt[, series := selected_label]

  plot_dt <- rbind(country_dt, region_dt, use.names = TRUE, fill = TRUE)
  pillar_short <- c(
    "SPI.INDEX.PIL1" = "Pillar 1:\nData Use",
    "SPI.INDEX.PIL2" = "Pillar 2:\nData Services",
    "SPI.INDEX.PIL3" = "Pillar 3:\nData Products",
    "SPI.INDEX.PIL4" = "Pillar 4:\nData Sources",
    "SPI.INDEX.PIL5" = "Pillar 5:\nData Infrastructure"
  )

  plot_dt[, pillar := factor(pillar, levels = pillars, labels = pillar_short[pillars])]
  plot_dt[, series := factor(series, levels = c(selected_label, paste0(region_name, " (aggregate)")))]

  wb_country <- "#0071BC"
  wb_reference <- "#8A969F"
  series_levels <- c(selected_label, paste0(region_name, " (aggregate)"))

  ggplot2::ggplot(plot_dt, ggplot2::aes(x = pillar, y = value, group = series)) +
    ggplot2::geom_polygon(
      ggplot2::aes(color = series, fill = series, linetype = series),
      linewidth = 1,
      alpha = 0.15
    ) +
    ggplot2::geom_point(ggplot2::aes(color = series), size = 2.2) +
    coord_radar() +
    ggplot2::scale_y_continuous(
      limits = c(0, 100),
      breaks = c(20, 40, 60, 80, 100)
    ) +
    ggplot2::scale_colour_manual(
      values = stats::setNames(c(wb_country, wb_reference), series_levels),
      name = NULL
    ) +
    ggplot2::scale_fill_manual(
      values = stats::setNames(c(wb_country, NA), series_levels),
      name = NULL
    ) +
    ggplot2::scale_linetype_manual(
      values = stats::setNames(c("solid", "dashed"), series_levels),
      name = NULL
    ) +
    ggplot2::labs(
      title = "SPI Pillar Performance",
      subtitle = paste0(selected_label, " vs. ", region_name, " regional aggregate  ·  ", as.integer(year)),
      x = NULL,
      y = NULL,
      caption = SPI_PLOT_CAPTION
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(colour = SPI_WB_GRID),
      axis.text.y = ggplot2::element_text(colour = SPI_WB_TEXT_SUBTLE, size = 8),
      axis.text.x = ggplot2::element_text(colour = SPI_WB_TEXT, face = "bold"),
      plot.title = ggplot2::element_text(face = "bold", colour = SPI_WB_TEXT),
      plot.subtitle = ggplot2::element_text(colour = SPI_WB_TEXT_SUBTLE),
      plot.caption = ggplot2::element_text(colour = SPI_WB_TEXT_SUBTLE),
      legend.position = "top"
    )
}
