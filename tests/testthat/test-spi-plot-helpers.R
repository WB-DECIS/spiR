# Tests for visualization shared helpers.

make_plot_index_dt <- function() {
  data.table::data.table(
    iso3c = c("CHL", "PER", "BOL"),
    date = c(2024L, 2024L, 2024L),
    country = c("Chile", "Peru", "Bolivia"),
    SPI.INDEX = c(72.1, -99, 40.0),
    SPI.INDEX.PIL1 = c(80, 70, 30)
  )
}

make_plot_data_dt <- function() {
  data.table::data.table(
    iso3c = c("CHL", "PER", "BOL"),
    date = c(2024L, 2024L, 2024L),
    country = c("Chile", "Peru", "Bolivia"),
    SPI.D2.1.GDDS = c(1, -99, 0)
  )
}

make_country_info_dt <- function() {
  data.table::data.table(
    date = c(2024L, 2024L, 2024L),
    iso3c = c("CHL", "PER", "BOL"),
    country = c("Chile", "Peru", "Bolivia"),
    region = c("Latin America & Caribbean", "Latin America & Caribbean", "Latin America & Caribbean"),
    population = c(1.0, 2.0, 3.0)
  )
}

test_that(".spi_plot_fetch() routes SPI.INDEX* to spi_index and converts -99 to NA", {
  called <- NULL
  mock_index <- function(version = "master", country = NULL, year = NULL,
                         pillar = NULL, dimension = NULL) {
    called <<- "index"
    make_plot_index_dt()
  }
  mock_data <- function(version = "master", country = NULL, year = NULL,
                        pillar = NULL, dimension = NULL) {
    called <<- "data"
    make_plot_data_dt()
  }

  local_mocked_bindings(spi_index = mock_index, spi_data = mock_data)

  result <- .spi_plot_fetch("SPI.INDEX", year = 2024L)
  expect_equal(called, "index")
  expect_s3_class(result, "data.table")
  expect_true("value" %in% names(result))
  expect_true(any(is.na(result[["value"]])))
})

test_that(".spi_plot_fetch() routes non-index SPI columns to spi_data", {
  called <- NULL
  mock_index <- function(version = "master", country = NULL, year = NULL,
                         pillar = NULL, dimension = NULL) {
    called <<- "index"
    make_plot_index_dt()
  }
  mock_data <- function(version = "master", country = NULL, year = NULL,
                        pillar = NULL, dimension = NULL) {
    called <<- "data"
    make_plot_data_dt()
  }

  local_mocked_bindings(spi_index = mock_index, spi_data = mock_data)

  result <- .spi_plot_fetch("SPI.D2.1.GDDS", year = 2024L)
  expect_equal(called, "data")
  expect_s3_class(result, "data.table")
})

test_that(".spi_plot_fetch() fails loudly when value_col is absent", {
  local_mocked_bindings(
    spi_index = function(...) make_plot_index_dt(),
    spi_data = function(...) make_plot_data_dt()
  )

  expect_error(
    .spi_plot_fetch("SPI.DOES.NOT.EXIST", year = 2024L),
    "not found"
  )
})

test_that(".spi_plot_scale() detects share and index scales", {
  s1 <- .spi_plot_scale(c(0.2, 0.8, NA_real_))
  expect_true(s1$is_share)
  expect_equal(s1$limits, c(0, 1))
  expect_equal(s1$digits, 3L)

  s2 <- .spi_plot_scale(c(20, 80, NA_real_))
  expect_false(s2$is_share)
  expect_equal(s2$limits, c(0, 100))
  expect_equal(s2$digits, 1L)
})

test_that(".spi_plot_join_meta() joins region/population and validates required cols", {
  plot_dt <- data.table::data.table(
    iso3c = c("CHL", "PER"),
    date = c(2024L, 2024L),
    country = c("Chile", "Peru"),
    value = c(1, 0)
  )

  local_mocked_bindings(
    country_info = function(version = "master", country = NULL, year = NULL) {
      make_country_info_dt()
    }
  )

  result <- .spi_plot_join_meta(plot_dt, cols = c("region", "population"))
  expect_true(all(c("region", "population") %in% names(result)))
})

test_that(".spi_plot_join_meta() aborts when required metadata columns are missing", {
  plot_dt <- data.table::data.table(
    iso3c = c("CHL"),
    date = c(2024L),
    country = c("Chile"),
    value = c(1)
  )

  local_mocked_bindings(
    country_info = function(version = "master", country = NULL, year = NULL) {
      data.table::data.table(iso3c = "CHL", date = 2024L, country = "Chile")
    }
  )

  expect_error(
    .spi_plot_join_meta(plot_dt, cols = c("region")),
    "Missing metadata"
  )
})
