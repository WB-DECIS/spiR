# Region pillar trajectories.

#' Plot region pillar trajectories over time
#'
#' @param region Character scalar with WB region name.
#' @param weighted Logical. TRUE for population-weighted average.
#' @param pillars Character vector of pillar columns.
#' @param version Character SPI branch.
#' @return A ggplot object.
#' @export
spi_plot_region_pillars <- function(region,
                                    weighted = TRUE,
                                    pillars = paste0("SPI.INDEX.PIL", 1:5),
                                    version = "master") {
  .spi_plot_check_deps(c("ggplot2", "wbplot"))

  if (!is.character(region) || length(region) != 1L || is.na(region)) {
    cli::cli_abort("{.arg region} must be a single character value.")
  }
  if (!is.logical(weighted) || length(weighted) != 1L || is.na(weighted)) {
    cli::cli_abort("{.arg weighted} must be a single logical value.")
  }
  if (!is.character(pillars) || length(pillars) == 0L || anyNA(pillars)) {
    cli::cli_abort("{.arg pillars} must be a non-empty character vector.")
  }

  dt <- spi_index(version = version)
  need <- unique(c("country", "iso3c", "date", pillars))
  missing <- setdiff(need, names(dt))
  if (length(missing) > 0L) {
    cli::cli_abort(c(
      "SPI index data is missing required pillar columns.",
      "x" = "Missing columns: {.field {missing}}."
    ))
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

  region_input <- trimws(region)
  long <- .spi_plot_join_meta(long, version = version, cols = c("region", "population"))
  long <- long[region == region_input]

  if (nrow(long) == 0L) {
    cli::cli_abort(c(
      "No rows found for requested region.",
      "x" = "Region input: {.val {region_input}}"
    ))
  }

  if (isTRUE(weighted)) {
    summary_dt <- long[!is.na(population), .(
      value = sum(value * as.numeric(population), na.rm = TRUE) /
        sum(as.numeric(population), na.rm = TRUE)
    ), by = .(pillar, date)]
    summary_dt[is.nan(value), value := NA_real_]
  } else {
    summary_dt <- long[, .(value = mean(value, na.rm = TRUE)), by = .(pillar, date)]
    summary_dt[is.nan(value), value := NA_real_]
  }

  data.table::setorder(summary_dt, pillar, date)

  ggplot2::ggplot(
    summary_dt,
    ggplot2::aes(x = date, y = value, color = pillar, group = pillar)
  ) +
    ggplot2::geom_line(linewidth = 1, lineend = "round", na.rm = FALSE) +
    ggplot2::geom_point(size = 1.8, na.rm = TRUE) +
    wbplot::scale_color_wb_d() +
    ggplot2::scale_y_continuous(limits = c(0, 100)) +
    ggplot2::labs(
      title = paste0("SPI pillars over time: ", region),
      x = NULL,
      y = "Score",
      color = NULL,
      caption = "Source: World Bank Statistical Performance Indicators (SPI)"
    ) +
    wbplot::theme_wb(chartType = "line")
}
