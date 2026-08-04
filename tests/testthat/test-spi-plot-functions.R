make_mock_index_plot_dt <- function() {
  data.table::data.table(
    iso3c = c("CHL", "PER", "BOL", "CHL", "PER", "BOL"),
    country = c("Chile", "Peru", "Bolivia", "Chile", "Peru", "Bolivia"),
    date = c(2023L, 2023L, 2023L, 2024L, 2024L, 2024L),
    SPI.INDEX = c(70, 60, 50, 72, 61, 52),
    SPI.INDEX.PIL1 = c(80, 70, 60, 81, 71, 62),
    SPI.INDEX.PIL2 = c(75, 65, 55, 76, 66, 56),
    SPI.INDEX.PIL3 = c(70, 60, 50, 71, 61, 51),
    SPI.INDEX.PIL4 = c(65, 55, 45, 66, 56, 46),
    SPI.INDEX.PIL5 = c(60, 50, 40, 61, 51, 41)
  )
}

make_mock_fetch_dt <- function() {
  data.table::data.table(
    iso3c = c("CHL", "PER", "BOL", "CHL", "PER", "BOL"),
    date = c(2023L, 2023L, 2023L, 2024L, 2024L, 2024L),
    country = c("Chile", "Peru", "Bolivia", "Chile", "Peru", "Bolivia"),
    value = c(0.70, 0.60, 0.50, 0.72, 0.61, 0.52)
  )
}

make_mock_fetch_meta_dt <- function() {
  dt <- make_mock_fetch_dt()
  dt[, region := c("Latin America & Caribbean", "Latin America & Caribbean", "Latin America & Caribbean", "Latin America & Caribbean", "Latin America & Caribbean", "Latin America & Caribbean")]
  dt[, population := c(10, 20, 30, 10, 20, 30)]
  dt
}

make_mock_aggregate_plot_dt <- function() {
  data.table::data.table(
    iso3c = c(
      "LAC", "LAC", "LAC", "LAC", "LAC", "LAC", "LAC",
      "LAC", "LAC", "LAC", "LAC", "LAC", "LAC", "LAC"
    ),
    date = c(
      2023L, 2024L, 2023L, 2024L, 2023L, 2024L, 2023L,
      2024L, 2023L, 2024L, 2023L, 2024L, 2023L, 2024L
    ),
    country = rep("Latin America & Caribbean", 14),
    source_id = c(
      "SPI.INDEX",
      "SPI.INDEX",
      "SPI.INDEX.PIL1",
      "SPI.INDEX.PIL1",
      "SPI.INDEX.PIL2",
      "SPI.INDEX.PIL2",
      "SPI.INDEX.PIL3",
      "SPI.INDEX.PIL3",
      "SPI.INDEX.PIL4",
      "SPI.INDEX.PIL4",
      "SPI.INDEX.PIL5",
      "SPI.INDEX.PIL5",
      "SPI.D1.1.TEST",
      "SPI.D1.1.TEST"
    ),
    value = c(58, 60, 68, 70, 63, 65, 58, 60, 53, 55, 48, 50, 0.30, 0.33)
  )
}

test_that("spi_plot_pillars() returns ggplot", {
  skip_if_not_installed("ggplot2")

  local_mocked_bindings(
    .spi_plot_check_deps = function(pkgs) invisible(NULL),
    spi_index = function(...) make_mock_index_plot_dt()
  )

  out <- spi_plot_pillars(country = "CHL")
  expect_s3_class(out, "ggplot")
})

test_that("spi_plot_trend() returns ggplot", {
  skip_if_not_installed("ggplot2")

  local_mocked_bindings(
    .spi_plot_check_deps = function(pkgs) invisible(NULL),
    .spi_plot_fetch = function(...) make_mock_fetch_dt()
  )

  out <- spi_plot_trend(countries = c("CHL", "PER"), value_col = "SPI.INDEX")
  expect_s3_class(out, "ggplot")
})

test_that("spi_plot_country_vs_region() returns ggplot", {
  skip_if_not_installed("ggplot2")

  local_mocked_bindings(
    .spi_plot_check_deps = function(pkgs) invisible(NULL),
    .spi_plot_fetch = function(...) make_mock_fetch_dt(),
    .spi_plot_fetch_aggregates = function(...) {
      data.table::data.table(
        region = c("Latin America & Caribbean", "Latin America & Caribbean"),
        date = c(2023L, 2024L),
        source_id = c("SPI.INDEX", "SPI.INDEX"),
        value = c(58, 60)
      )
    },
    .spi_plot_join_meta = function(dt, ...) {
      dt[, region := "Latin America & Caribbean"]
      dt
    }
  )

  out <- spi_plot_country_vs_region(country = "CHL", value_col = "SPI.INDEX")
  expect_s3_class(out, "ggplot")
})

test_that("spi_plot_radar() returns ggplot", {
  skip_if_not_installed("ggplot2")

  local_mocked_bindings(
    .spi_plot_check_deps = function(pkgs) invisible(NULL),
    spi_index = function(...) make_mock_index_plot_dt(),
    .spi_plot_fetch_aggregates = function(...) {
      data.table::data.table(
        region = rep("Latin America & Caribbean", 5),
        date = rep(2024L, 5),
        source_id = paste0("SPI.INDEX.PIL", 1:5),
        value = c(70, 65, 60, 55, 50)
      )
    },
    .spi_plot_join_meta = function(dt, ...) {
      dt[, region := "Latin America & Caribbean"]
      dt
    }
  )

  out <- spi_plot_radar(country = "CHL", year = 2024L)
  expect_s3_class(out, "ggplot")
})

test_that("spi_plot_regions() returns ggplot", {
  skip_if_not_installed("ggplot2")

  local_mocked_bindings(
    .spi_plot_check_deps = function(pkgs) invisible(NULL),
    .spi_plot_fetch_aggregates = function(...) {
      data.table::data.table(
        region = c("Latin America & Caribbean", "Latin America & Caribbean"),
        date = c(2023L, 2024L),
        source_id = c("SPI.INDEX", "SPI.INDEX"),
        value = c(58, 60)
      )
    }
  )

  out <- spi_plot_regions(value_col = "SPI.INDEX")
  expect_s3_class(out, "ggplot")
})

test_that("spi_plot_regions() rejects multiple value columns", {
  skip_if_not_installed("ggplot2")

  expect_error(
    spi_plot_regions(value_col = c("SPI.INDEX", "SPI.INDEX.PIL1")),
    "single non-empty character"
  )
})

test_that("spi_plot_region_pillars() returns ggplot", {
  skip_if_not_installed("ggplot2")

  local_mocked_bindings(
    .spi_plot_check_deps = function(pkgs) invisible(NULL),
    .spi_plot_fetch_aggregates = function(...) {
      data.table::data.table(
        region = rep("Latin America & Caribbean", 10),
        date = rep(c(2023L, 2024L), 5),
        source_id = rep(paste0("SPI.INDEX.PIL", 1:5), each = 2),
        value = c(68, 70, 63, 65, 58, 60, 53, 55, 48, 50)
      )
    }
  )

  out <- spi_plot_region_pillars(region = "Latin America & Caribbean", weighted = TRUE)
  expect_s3_class(out, "ggplot")
})

test_that("spi_plot_region_pillars() aborts when weighted = FALSE", {
  local_mocked_bindings(
    .spi_plot_check_deps = function(pkgs) invisible(NULL)
  )

  expect_error(
    spi_plot_region_pillars(
      region = "Latin America & Caribbean",
      weighted = FALSE
    ),
    "official SPI regional aggregates"
  )
})
