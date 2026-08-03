# Simple visual smoke-test for spiR plotting helpers.
# Run from project root:
#   source("run_viz_examples.R")

run_spi_viz_examples <- function(
  version = "master",
  country = "CHL",
  countries = c("CHL", "PER"),
  region = "Latin America & Caribbean",
  regions = c("Latin America & Caribbean", "Europe & Central Asia"),
  year = 2024L,
  value_col = "SPI.INDEX",
  output_dir = file.path(getwd(), "viz_examples_output"),
  save_files = TRUE,
  save_interactive_map = FALSE
) {
  if (requireNamespace("pkgload", quietly = TRUE)) {
    pkgload::load_all(".", quiet = TRUE)
  } else if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all(".", quiet = TRUE)
  } else {
    stop("Install pkgload or devtools to load local spiR code.", call. = FALSE)
  }

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Install ggplot2 before running examples.", call. = FALSE)
  }

  if (isTRUE(save_files)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  cat("Running simple visualization examples...\n")

  p_pillars <- spi_plot_pillars(country = country, version = version)
  p_trend <- spi_plot_trend(countries = countries, value_col = value_col, version = version)
  p_country_vs_region <- spi_plot_country_vs_region(country = country, value_col = value_col, version = version)
  p_radar <- spi_plot_radar(country = country, year = year, version = version)
  p_regions <- spi_plot_regions(regions = regions, value_col = value_col, version = version)
  p_region_pillars <- spi_plot_region_pillars(region = region, weighted = TRUE, version = version)
  p_map_static <- spi_plot_map(value_col = value_col, year = year, interactive = TRUE, version = version)

  print(p_pillars)
  print(p_trend)
  print(p_country_vs_region)
  print(p_radar)
  print(p_regions)
  print(p_region_pillars)
  print(p_map_static)

  map_interactive <- NULL
  if (isTRUE(save_interactive_map)) {
    if (!requireNamespace("ggiraph", quietly = TRUE)) {
      stop("Install ggiraph to generate interactive map.", call. = FALSE)
    }
    map_interactive <- spi_plot_map(
      value_col = value_col,
      year = year,
      country = country,
      interactive = TRUE,
      version = version
    )
    print(map_interactive)
  }

  if (isTRUE(save_files)) {
    ggplot2::ggsave(file.path(output_dir, "01_pillars.png"), p_pillars, width = 10, height = 6, dpi = 300)
    ggplot2::ggsave(file.path(output_dir, "02_trend.png"), p_trend, width = 10, height = 6, dpi = 300)
    ggplot2::ggsave(file.path(output_dir, "03_country_vs_region.png"), p_country_vs_region, width = 10, height = 6, dpi = 300)
    ggplot2::ggsave(file.path(output_dir, "04_radar.png"), p_radar, width = 9, height = 7, dpi = 300)
    ggplot2::ggsave(file.path(output_dir, "05_regions.png"), p_regions, width = 10, height = 6, dpi = 300)
    ggplot2::ggsave(file.path(output_dir, "06_region_pillars.png"), p_region_pillars, width = 10, height = 6, dpi = 300)
    ggplot2::ggsave(file.path(output_dir, "07_map_static.png"), p_map_static, width = 11, height = 6, dpi = 300)

    if (isTRUE(save_interactive_map)) {
      if (!requireNamespace("htmlwidgets", quietly = TRUE)) {
        stop("Install htmlwidgets to save interactive map HTML.", call. = FALSE)
      }
      htmlwidgets::saveWidget(
        map_interactive,
        file = file.path(output_dir, "08_map_interactive.html"),
        selfcontained = TRUE
      )
    }

    cat("Saved files in:\n")
    cat(normalizePath(output_dir, winslash = "/", mustWork = FALSE), "\n")
  }

  invisible(list(
    pillars = p_pillars,
    trend = p_trend,
    country_vs_region = p_country_vs_region,
    radar = p_radar,
    regions = p_regions,
    region_pillars = p_region_pillars,
    map_static = p_map_static,
    map_interactive = map_interactive
  ))
}

run_spi_viz_examples()
