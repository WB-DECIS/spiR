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

test_that("spi_plot_pillars() returns ggplot", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("wbplot")

  local_mocked_bindings(
    .spi_plot_check_deps = function(pkgs) invisible(NULL),
    spi_index = function(...) make_mock_index_plot_dt()
  )

  out <- spi_plot_pillars(country = "CHL")
  expect_s3_class(out, "ggplot")
})

test_that("spi_plot_trend() returns ggplot", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("wbplot")

  local_mocked_bindings(
    .spi_plot_check_deps = function(pkgs) invisible(NULL),
    .spi_plot_fetch = function(...) make_mock_fetch_dt()
  )

  out <- spi_plot_trend(countries = c("CHL", "PER"), value_col = "SPI.INDEX")
  expect_s3_class(out, "ggplot")
})

test_that("spi_plot_country_vs_region() returns ggplot", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("wbplot")

  local_mocked_bindings(
    .spi_plot_check_deps = function(pkgs) invisible(NULL),
    .spi_plot_fetch = function(...) make_mock_fetch_dt(),
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
  skip_if_not_installed("wbplot")

  local_mocked_bindings(
    .spi_plot_check_deps = function(pkgs) invisible(NULL),
    spi_index = function(...) make_mock_index_plot_dt(),
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
  skip_if_not_installed("wbplot")

  local_mocked_bindings(
    .spi_plot_check_deps = function(pkgs) invisible(NULL),
    .spi_plot_fetch = function(...) make_mock_fetch_dt(),
    .spi_plot_join_meta = function(dt, ...) {
      dt[, region := "Latin America & Caribbean"]
      dt
    }
  )

  out <- spi_plot_regions(value_col = "SPI.INDEX")
  expect_s3_class(out, "ggplot")
})

test_that("spi_plot_region_pillars() returns ggplot", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("wbplot")

  local_mocked_bindings(
    .spi_plot_check_deps = function(pkgs) invisible(NULL),
    spi_index = function(...) make_mock_index_plot_dt(),
    .spi_plot_join_meta = function(dt, ...) {
      dt[, region := "Latin America & Caribbean"]
      dt[, population := 10]
      dt
    }
  )

  out <- spi_plot_region_pillars(region = "Latin America & Caribbean", weighted = TRUE)
  expect_s3_class(out, "ggplot")
})
