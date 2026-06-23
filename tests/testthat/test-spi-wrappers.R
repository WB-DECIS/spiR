# Tests for the convenience wrappers spi_data(), spi_index(),
# spi_aggregates(). spi_get() is mocked to verify delegation.

# ---------------------------------------------------------------------------
# Mock
# ---------------------------------------------------------------------------

# Capture calls made to spi_get() so we can assert arguments
spi_get_call_log <- NULL

mock_spi_get <- function(type = "data",
                         version = "master",
                         country = NULL,
                         year = NULL,
                         pillar = NULL,
                         dimension = NULL,
                         region = NULL) {
  spi_get_call_log <<- list(
    type      = type,
    version   = version,
    country   = country,
    year      = year,
    pillar    = pillar,
    dimension = dimension,
    region    = region
  )
  data.table::data.table()  # return empty dt
}

# ---------------------------------------------------------------------------
# spi_data()
# ---------------------------------------------------------------------------

test_that("spi_data() calls spi_get() with type = 'data'", {
  local_mocked_bindings(spi_get = mock_spi_get)
  spi_data()
  expect_equal(spi_get_call_log$type, "data")
})

test_that("spi_data() passes country, year, pillar, dimension", {
  local_mocked_bindings(spi_get = mock_spi_get)
  spi_data(
    version   = "SPI2023",
    country   = c("NOR", "SWE"),
    year      = 2024L,
    pillar    = 3L,
    dimension = "3.1"
  )
  expect_equal(spi_get_call_log$version,   "SPI2023")
  expect_equal(spi_get_call_log$country,   c("NOR", "SWE"))
  expect_equal(spi_get_call_log$year,      2024L)
  expect_equal(spi_get_call_log$pillar,    3L)
  expect_equal(spi_get_call_log$dimension, "3.1")
  expect_null(spi_get_call_log$region)
})

test_that("spi_data() returns data.table", {
  local_mocked_bindings(spi_get = mock_spi_get)
  result <- spi_data()
  expect_s3_class(result, "data.table")
})

# ---------------------------------------------------------------------------
# spi_index()
# ---------------------------------------------------------------------------

test_that("spi_index() calls spi_get() with type = 'index'", {
  local_mocked_bindings(spi_get = mock_spi_get)
  spi_index()
  expect_equal(spi_get_call_log$type, "index")
})

test_that("spi_index() passes all arguments correctly", {
  local_mocked_bindings(spi_get = mock_spi_get)
  spi_index(country = "KEN", year = 2022L, pillar = 5L)
  expect_equal(spi_get_call_log$country, "KEN")
  expect_equal(spi_get_call_log$year,    2022L)
  expect_equal(spi_get_call_log$pillar,  5L)
  expect_null(spi_get_call_log$region)
})

# ---------------------------------------------------------------------------
# spi_aggregates()
# ---------------------------------------------------------------------------

test_that("spi_aggregates() calls spi_get() with type = 'aggregates'", {
  local_mocked_bindings(spi_get = mock_spi_get)
  spi_aggregates()
  expect_equal(spi_get_call_log$type, "aggregates")
})

test_that("spi_aggregates() passes region, year, pillar, dimension", {
  local_mocked_bindings(spi_get = mock_spi_get)
  spi_aggregates(
    region    = "Africa Eastern and Southern",
    year      = 2024L,
    pillar    = 1L,
    dimension = "1.5"
  )
  expect_equal(spi_get_call_log$region,    "Africa Eastern and Southern")
  expect_equal(spi_get_call_log$year,      2024L)
  expect_equal(spi_get_call_log$pillar,    1L)
  expect_equal(spi_get_call_log$dimension, "1.5")
  expect_null(spi_get_call_log$country)
})

test_that("spi_aggregates() does not pass country argument", {
  local_mocked_bindings(spi_get = mock_spi_get)
  spi_aggregates()
  expect_null(spi_get_call_log$country)
})

# ---------------------------------------------------------------------------
# P2.10 — behavioral tests (real spi_get() call, only spi_download() mocked)
# ---------------------------------------------------------------------------

make_mock_data_for_wrappers <- function() {
  data.table::data.table(
    iso3c     = c("NOR", "SWE"),
    date      = c(2024L, 2024L),
    country   = c("Norway", "Sweden"),
    SPI.INDEX = c(94.1, 92.7)
  )
}

make_mock_index_for_wrappers <- function() {
  data.table::data.table(
    iso3c        = c("NOR", "SWE"),
    date         = c(2024L, 2024L),
    country      = c("Norway", "Sweden"),
    SPI.INDEX    = c(94.1, 92.7),
    SPI.D1.5.POV = c(1, 1)
  )
}

make_mock_agg_for_wrappers <- function() {
  data.table::data.table(
    iso3c     = c("AFE", "NOR"),     # NOR is a country row — should be dropped
    country   = c("Africa Eastern and Southern", "Norway"),
    date      = c(2024L, 2024L),
    source_id = c("SPI.D1.5.POV", "SPI.D1.5.POV"),
    value     = c(0.5, 1.0)
  )
}

mock_spi_download_wrappers <- function(file_path, version = "master") {
  if (grepl("SPI_index", file_path))   return(make_mock_index_for_wrappers())
  if (grepl("aggregates", file_path))  return(make_mock_agg_for_wrappers())
  make_mock_data_for_wrappers()
}

test_that("spi_data() returns correct rows when country filter applied (P2.10)", {
  local_mocked_bindings(spi_download = mock_spi_download_wrappers)
  result <- spi_data(country = "NOR")
  expect_equal(nrow(result), 1L)
  expect_equal(result[["iso3c"]], "NOR")
})

test_that("spi_data() keeps only id columns and indicator payload columns", {
  local_mocked_bindings(spi_download = mock_spi_download_wrappers)
  result <- spi_data()
  expect_setequal(names(result), c("iso3c", "date", "country"))
})

test_that("spi_index() returns a data.table with SPI.INDEX column (P2.10)", {
  local_mocked_bindings(spi_download = mock_spi_download_wrappers)
  result <- spi_index()
  expect_s3_class(result, "data.table")
  expect_true("SPI.INDEX" %in% names(result))
})

test_that("spi_index() keeps only id columns and index payload columns", {
  local_mocked_bindings(spi_download = mock_spi_download_wrappers)
  result <- spi_index()
  expect_setequal(
    names(result),
    c("iso3c", "date", "country", "SPI.INDEX", "SPI.D1.5.POV")
  )
})

test_that("spi_aggregates() excludes individual country rows (P2.10)", {
  local_mocked_bindings(spi_download = mock_spi_download_wrappers)
  result <- spi_aggregates()
  # "NOR" in the mock aggregates dt is a country row — should be filtered out
  expect_false("NOR" %in% result[["iso3c"]])
  expect_true(nrow(result) > 0L)
})

test_that("spi_aggregates() keeps only id columns and aggregate value payload", {
  local_mocked_bindings(spi_download = mock_spi_download_wrappers)
  result <- spi_aggregates()
  expect_setequal(names(result), c("iso3c", "date", "country", "source_id", "value"))
})

# ---------------------------------------------------------------------------
# spi_indicator()
# ---------------------------------------------------------------------------

mock_spi_get_for_indicator <- function(type = "data",
                                       version = "master",
                                       country = NULL,
                                       year = NULL,
                                       pillar = NULL,
                                       dimension = NULL,
                                       region = NULL) {
  spi_get_call_log <<- list(
    type      = type,
    version   = version,
    country   = country,
    year      = year,
    pillar    = pillar,
    dimension = dimension,
    region    = region
  )
  data.table::data.table(
    iso3c        = "NOR",
    date         = 2024L,
    country      = "Norway",
    SPI.D1.5.POV = 1,
    RAW.D1.5.POV = 1
  )
}

mock_spi_get_for_indicator_no_raw <- function(type = "data",
                                              version = "master",
                                              country = NULL,
                                              year = NULL,
                                              pillar = NULL,
                                              dimension = NULL,
                                              region = NULL) {
  spi_get_call_log <<- list(
    type      = type,
    version   = version,
    country   = country,
    year      = year,
    pillar    = pillar,
    dimension = dimension,
    region    = region
  )
  data.table::data.table(
    iso3c        = "NOR",
    date         = 2024L,
    country      = "Norway",
    SPI.D1.5.POV = 1
  )
}

test_that("spi_indicator() calls spi_get() with type = 'data'", {
  local_mocked_bindings(spi_get = mock_spi_get_for_indicator)
  spi_indicator("SPI.D1.5.POV")
  expect_equal(spi_get_call_log$type, "data")
})

test_that("spi_indicator() forwards version, country, and year to spi_get()", {
  local_mocked_bindings(spi_get = mock_spi_get_for_indicator)
  spi_indicator(
    indicator = "SPI.D1.5.POV",
    version   = "SPI2023",
    country   = "KEN",
    year      = 2022:2024
  )
  expect_equal(spi_get_call_log$version, "SPI2023")
  expect_equal(spi_get_call_log$country, "KEN")
  expect_equal(spi_get_call_log$year, 2022:2024)
})

test_that("spi_indicator() includes requested SPI indicator columns", {
  local_mocked_bindings(spi_get = mock_spi_get_for_indicator)
  result <- spi_indicator("SPI.D1.5.POV")
  expect_s3_class(result, "data.table")
  expect_true("SPI.D1.5.POV" %in% names(result))
})

test_that("spi_indicator() returns raw columns when include_raw = TRUE", {
  local_mocked_bindings(spi_get = mock_spi_get_for_indicator)
  result <- spi_indicator("SPI.D1.5.POV", include_raw = TRUE)
  expect_true("RAW.D1.5.POV" %in% names(result))
})

test_that("spi_indicator() does not error when include_raw = TRUE but raw column is absent", {
  local_mocked_bindings(spi_get = mock_spi_get_for_indicator_no_raw)
  result <- spi_indicator("SPI.D1.5.POV", include_raw = TRUE)
  expect_false("RAW.D1.5.POV" %in% names(result))
  expect_true("SPI.D1.5.POV" %in% names(result))
})

test_that("spi_indicator() errors when indicator names are invalid", {
  expect_error(
    spi_indicator("INVALID"),
    "must contain valid SPI indicator column names"
  )
})

test_that("spi_indicator() errors when indicator is NULL", {
  expect_error(
    spi_indicator(NULL),
    "must be a non-empty character vector"
  )
})

test_that("spi_indicator() errors when indicator contains NA", {
  expect_error(
    spi_indicator(NA_character_),
    "must be a non-empty character vector"
  )
})

test_that("spi_indicator() errors when a valid indicator name is absent from the data", {
  local_mocked_bindings(spi_get = mock_spi_get_for_indicator)
  expect_error(
    spi_indicator("SPI.D2.1.GDDS"),
    "Requested indicator columns are not available"
  )
})

test_that("spi_indicator() errors when only some requested indicators are present", {
  local_mocked_bindings(spi_get = mock_spi_get_for_indicator)
  expect_error(
    spi_indicator(c("SPI.D1.5.POV", "SPI.D2.1.GDDS")),
    "Missing columns"
  )
})
