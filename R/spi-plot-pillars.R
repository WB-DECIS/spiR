# Pillar time-series plots for a single country.

#' Plot SPI pillar trajectories over time for one country
#'
#' @param country Character scalar with country name or ISO3 code.
#' @param pillars Character vector with pillar columns.
#' @param version Character SPI branch.
#' @return A ggplot object.
#' @export
spi_plot_pillars <- function(country,
                             pillars = paste0("SPI.INDEX.PIL", 1:5),
                             version = "master") {
  .spi_plot_check_deps(c("ggplot2", "wbplot"))

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
    wbplot::scale_color_wb_d() +
    ggplot2::labs(
      title = paste0("SPI pillars over time: ", selected_name),
      x = NULL,
      y = "Score",
      color = NULL,
      caption = "Source: World Bank Statistical Performance Indicators (SPI)"
    ) +
    wbplot::theme_wb(chartType = "line")
}
