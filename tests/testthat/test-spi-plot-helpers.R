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

make_plot_aggregate_dt <- function() {
  data.table::data.table(
    iso3c = c("LAC", "LAC", "LAC"),
    date = c(2024L, 2024L, 2024L),
    country = c(
      "Latin America & Caribbean",
      "Latin America & Caribbean",
      "Latin America & Caribbean"
    ),
    source_id = c("SPI.INDEX", "SPI.INDEX.PIL1", "SPI.D2.1.GDDS"),
    value = c(72.1, -99, 0.5)
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

test_that(".spi_plot_fetch_aggregates() returns normalized aggregate rows", {
  local_mocked_bindings(
    spi_aggregates = function(version = "master", region = NULL, year = NULL,
                              pillar = NULL, dimension = NULL) {
      make_plot_aggregate_dt()
    }
  )

  result <- .spi_plot_fetch_aggregates("SPI.INDEX.PIL1", region = "Latin America & Caribbean")
  expect_s3_class(result, "data.table")
  expect_true(all(c("region", "date", "source_id", "value") %in% names(result)))
  expect_true(is.na(result$value[1]))
})

test_that(".spi_plot_fetch_aggregates() rejects RAW columns", {
  expect_error(
    .spi_plot_fetch_aggregates("RAW.D2.1.GDDS"),
    "RAW columns are not available"
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

test_that(".spi_plot_floor_year_to_five() rounds down to previous five-year mark", {
  expect_equal(.spi_plot_floor_year_to_five(2016L), 2015L)
  expect_equal(.spi_plot_floor_year_to_five(2015L), 2015L)
  expect_equal(.spi_plot_floor_year_to_five(2000L), 2000L)
})

test_that(".spi_plot_time_axis_spec() starts from first non-missing value year", {
  dt <- data.table::data.table(
    date = c(2005L, 2006L, 2016L, 2017L, 2025L),
    value = c(NA_real_, NA_real_, 55, 58, 63)
  )

  spec <- .spi_plot_time_axis_spec(dt)

  expect_equal(spec$start_year, 2015L)
  expect_equal(spec$end_year, 2025L)
  expect_true(spec$limits[2] > 2025)
  expect_true(2015L %in% spec$breaks)
  expect_true(2025L %in% spec$breaks)
})

test_that(".spi_plot_latest_points() keeps latest non-missing observation per series", {
  dt <- data.table::data.table(
    series = c("A", "A", "A", "B", "B", "C", "C"),
    date = c(2022L, 2023L, 2024L, 2023L, 2024L, 2022L, 2023L),
    value = c(1, NA_real_, 3, 2, NA_real_, NA_real_, NA_real_),
    code = c("A", "A", "A", "B", "B", "C", "C")
  )

  latest <- .spi_plot_latest_points(
    dt = dt,
    series_col = "series",
    code_col = "code"
  )

  expect_equal(nrow(latest), 2L)
  expect_setequal(latest$series, c("A", "B"))
  expect_equal(latest[series == "A"]$date, 2024L)
  expect_equal(latest[series == "B"]$date, 2023L)
})

test_that(".spi_plot_display_label() resolves metadata names by stable IDs", {
  local_mocked_bindings(
    metadata = function(version = "master", ...) {
      list(
        pillars = data.table::data.table(
          pillar = c("1", "2"),
          pillar_name = c("Pillar 1: Data Use", "Data Services"),
          pillar_id = c("SPI.INDEX.PIL1", "SPI.INDEX.PIL2")
        ),
        dimensions = data.table::data.table(
          pillar = c("2"),
          dimension = c("2.1"),
          dimension_name = c("Dimension 2.1: Use of Administrative Data"),
          dimension_id = c("SPI.DIM2.1.INDEX")
        ),
        indicators = data.table::data.table(
          pillar = c("2"),
          dimension = c("2.1"),
          indicator = c("2.1.1"),
          indicator_name = c("Has GDDS metadata"),
          indicator_id = c("SPI.D2.1.GDDS")
        )
      )
    }
  )

  expect_equal(.spi_plot_display_label("SPI.INDEX"), "SPI Index")
  expect_equal(.spi_plot_display_label("SPI.INDEX.PIL1"), "Pillar 1: Data Use")
  expect_equal(
    .spi_plot_display_label("SPI.DIM2.1.INDEX"),
    "Dimension 2.1: Use of Administrative Data"
  )
  expect_equal(
    .spi_plot_display_label("SPI.D2.1.GDDS"),
    "Indicator SPI.D2.1.GDDS: Has GDDS metadata"
  )
})
