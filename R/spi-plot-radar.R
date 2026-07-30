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

#' Radar chart of SPI pillars for one country vs region average
#'
#' @param country Character scalar with country name or ISO3 code.
#' @param year Integer year to display.
#' @param version Character SPI branch.
#' @return A ggplot object.
#' @export
spi_plot_radar <- function(country,
                           year,
                           version = "master") {
  .spi_plot_check_deps(c("ggplot2", "wbplot"))

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

  region_dt <- long[region == region_name, .(
    value = mean(value, na.rm = TRUE)
  ), by = .(pillar)]
  region_dt[is.nan(value), value := NA_real_]
  region_dt[, series := paste0(region_name, " (avg.)")]

  country_dt <- country_dt[, .(pillar, value)]
  country_dt[, series := unique(country_label)[1]]

  plot_dt <- rbind(country_dt, region_dt, use.names = TRUE, fill = TRUE)
  plot_dt[, pillar := factor(pillar, levels = pillars)]

  ggplot2::ggplot(plot_dt, ggplot2::aes(x = pillar, y = value, group = series)) +
    ggplot2::geom_polygon(
      ggplot2::aes(color = series, fill = series, linetype = series),
      linewidth = 1,
      alpha = 0.15
    ) +
    ggplot2::geom_point(ggplot2::aes(color = series), size = 2) +
    ggplot2::coord_polar() +
    ggplot2::scale_y_continuous(limits = c(0, 100)) +
    wbplot::scale_color_wb_d() +
    wbplot::scale_fill_wb_d() +
    ggplot2::labs(
      title = paste0("SPI pillars radar | ", as.integer(year)),
      x = NULL,
      y = NULL,
      color = NULL,
      fill = NULL,
      linetype = NULL,
      caption = "Source: World Bank Statistical Performance Indicators (SPI)"
    ) +
    wbplot::theme_wb(chartType = "line")
}
