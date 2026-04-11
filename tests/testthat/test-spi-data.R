# Tests for spi_get(). All unit tests — spi_download() is mocked.

# ---------------------------------------------------------------------------
# Mock setup
# ---------------------------------------------------------------------------

make_mock_data_dt <- function() {
  data.table::data.table(
    iso3c              = c("NOR", "SWE", "AFG", "KEN"),
    date               = c(2024L, 2024L, 2023L, 2023L),
    country            = c("Norway", "Sweden", "Afghanistan", "Kenya"),
    SPI.D1.5.POV       = c(1, 1, 0, 0.5),
    SPI.D1.5.CHLD.MORT = c(1, 1, 1, 0.8),
    RAW.D1.5.POV       = c(1, 1, 0, 0.5),
    SPI.D3.1.POV       = c(1, 0.9, 0, 0.4),
    RAW.D3.1.POV       = c(1, 0.9, 0, 0.4),
    SPI.INDEX          = c(94.1, 92.7, 30.0, 55.0),
    region             = c("ECS", "ECS", "SAS", "SSF"),
    income_level       = c("High income", "High income", "Low income", "Low income")
  )
}

make_mock_index_dt <- function() {
  data.table::data.table(
    country          = c("Norway", "Sweden", "Afghanistan"),
    iso3c            = c("NOR", "SWE", "AFG"),
    date             = c(2024L, 2024L, 2023L),
    SPI.INDEX        = c(94.1, 92.7, 30.0),
    SPI.INDEX.PIL1   = c(100, 100, 5),
    SPI.D1.5.POV     = c(1, 1, 0),
    SPI.D3.1.POV     = c(1, 0.9, 0),
    income           = c("High income", "High income", "Low income"),
    region           = c("Europe & Central Asia", "Europe & Central Asia", "South Asia")
  )
}

make_mock_agg_dt <- function() {
  data.table::data.table(
    iso3c     = c("AFE", "AFE", "WLD", "WLD", "NOR"),  # NOR is a country row
    country   = c(
      "Africa Eastern and Southern", "Africa Eastern and Southern",
      "World", "World", "Norway"
    ),
    date      = c(2024L, 2023L, 2024L, 2023L, 2024L),
    source_id = c(
      "SPI.D1.5.POV", "SPI.D1.5.POV",
      "SPI.D3.1.POV", "SPI.D3.1.POV",
      "SPI.D1.5.POV"
    ),
    value     = c(0.5, 0.4, 0.7, 0.65, 1.0)
  )
}

mock_spi_download <- function(file_path, version = "master") {
  if (grepl("SPI_data", file_path))    return(make_mock_data_dt())
  if (grepl("SPI_index", file_path))   return(make_mock_index_dt())
  if (grepl("aggregates", file_path))  return(make_mock_agg_dt())
  stop("Unknown file_path in mock: ", file_path)
}

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------

test_that("spi_get() rejects invalid type", {
  expect_error(spi_get(type = "invalid"), "should be one of")
})

test_that("spi_get() rejects non-character version", {
  expect_error(spi_get(version = 42), "`version`")
})

test_that("spi_get() rejects vector version", {
  expect_error(spi_get(version = c("master", "v2")), "`version`")
})

test_that("spi_get() rejects country with aggregates type", {
  expect_error(
    spi_get("aggregates", country = "NOR"),
    "country|aggregates",
    ignore.case = TRUE
  )
})

test_that("spi_get() rejects region with data type", {
  expect_error(
    spi_get("data", region = "Africa Eastern and Southern"),
    "region"
  )
})

test_that("spi_get() rejects region with index type", {
  expect_error(
    spi_get("index", region = "Africa Eastern and Southern"),
    "region"
  )
})

test_that("spi_get() rejects pillar out of range", {
  expect_error(spi_get("data", pillar = 6), "`pillar`")
  expect_error(spi_get("data", pillar = 0), "`pillar`")
  expect_error(spi_get("data", pillar = -1), "`pillar`")
})

test_that("spi_get() rejects non-numeric pillar", {
  expect_error(spi_get("data", pillar = "3"), "`pillar`")
})

test_that("spi_get() rejects badly formatted dimension", {
  expect_error(spi_get("data", dimension = "5"), "`dimension`")
  expect_error(spi_get("data", dimension = "pillar5"), "`dimension`")
  expect_error(spi_get("data", dimension = 5.2), "`dimension`")
})

# ---------------------------------------------------------------------------
# Filtering — data type
# ---------------------------------------------------------------------------

test_that("spi_get('data') returns data.table", {
  local_mocked_bindings(spi_download = mock_spi_download)
  result <- spi_get("data")
  expect_s3_class(result, "data.table")
})

test_that("spi_get('data') filters rows by country", {
  local_mocked_bindings(spi_download = mock_spi_download)
  result <- spi_get("data", country = "NOR")
  expect_equal(nrow(result), 1L)
  expect_equal(result[["iso3c"]], "NOR")
})

test_that("spi_get('data') filters rows by multiple countries", {
  local_mocked_bindings(spi_download = mock_spi_download)
  result <- spi_get("data", country = c("NOR", "SWE"))
  expect_equal(nrow(result), 2L)
  expect_setequal(result[["iso3c"]], c("NOR", "SWE"))
})

test_that("spi_get('data') filters rows by year", {
  local_mocked_bindings(spi_download = mock_spi_download)
  result <- spi_get("data", year = 2024L)
  expect_true(all(result[["date"]] == 2024L))
})

test_that("spi_get('data') returns empty data.table when no rows match", {
  local_mocked_bindings(spi_download = mock_spi_download)
  result <- spi_get("data", country = "ZZZ")
  expect_s3_class(result, "data.table")
  expect_equal(nrow(result), 0L)
})

test_that("spi_get('data') filters columns by pillar", {
  local_mocked_bindings(spi_download = mock_spi_download)
  result <- spi_get("data", pillar = 1L)
  expect_true("SPI.D1.5.POV" %in% names(result))
  expect_false("SPI.D3.1.POV" %in% names(result))
  expect_true("iso3c" %in% names(result))
})

test_that("spi_get('data') filters columns by dimension", {
  local_mocked_bindings(spi_download = mock_spi_download)
  result <- spi_get("data", dimension = "1.5")
  expect_true("SPI.D1.5.POV" %in% names(result))
  expect_false("SPI.D3.1.POV" %in% names(result))
})

test_that("spi_get('data') dimension overrides pillar for column filtering", {
  local_mocked_bindings(spi_download = mock_spi_download)
  result <- spi_get("data", pillar = 3L, dimension = "1.5")
  expect_true("SPI.D1.5.POV" %in% names(result))
  expect_false("SPI.D3.1.POV" %in% names(result))
})

# ---------------------------------------------------------------------------
# Filtering — aggregates type
# ---------------------------------------------------------------------------

test_that("spi_get('aggregates') returns only region rows", {
  local_mocked_bindings(spi_download = mock_spi_download)
  result <- spi_get("aggregates")
  expect_false("NOR" %in% result[["iso3c"]])
  expect_true(all(result[["iso3c"]] %in% SPI_AGGREGATE_CODES))
})

test_that("spi_get('aggregates') filters by region name", {
  local_mocked_bindings(spi_download = mock_spi_download)
  result <- spi_get("aggregates", region = "Africa Eastern and Southern")
  expect_true(all(result[["country"]] == "Africa Eastern and Southern"))
})

test_that("spi_get('aggregates') filters by year", {
  local_mocked_bindings(spi_download = mock_spi_download)
  result <- spi_get("aggregates", year = 2024L)
  expect_true(all(result[["date"]] == 2024L))
})

test_that("spi_get('aggregates') filters by pillar via source_id", {
  local_mocked_bindings(spi_download = mock_spi_download)
  result <- spi_get("aggregates", pillar = 1L)
  expect_true(all(grepl("^SPI\\.D1\\.", result[["source_id"]])))
})

test_that("spi_get('aggregates') filters by dimension via source_id", {
  local_mocked_bindings(spi_download = mock_spi_download)
  result <- spi_get("aggregates", dimension = "1.5")
  expect_true(all(grepl("^SPI\\.D1\\.5\\.", result[["source_id"]])))
})

test_that("spi_get('aggregates') returns data.table", {
  local_mocked_bindings(spi_download = mock_spi_download)
  result <- spi_get("aggregates")
  expect_s3_class(result, "data.table")
})

# ---------------------------------------------------------------------------
# P1.1 — year type validation
# ---------------------------------------------------------------------------

test_that("spi_get() rejects character year (P1.1)", {
  expect_error(spi_get("data", year = "2024"), "year")
})

test_that("spi_get() rejects NA year (P1.1)", {
  expect_error(spi_get("data", year = NA_integer_), "year")
})

test_that("spi_get() rejects vector with mixed NA year (P1.1)", {
  expect_error(spi_get("data", year = c(2023L, NA_integer_)), "year")
})

# ---------------------------------------------------------------------------
# P1.2 — country / region NA validation
# ---------------------------------------------------------------------------

test_that("spi_get() rejects country = NA (P1.2)", {
  expect_error(spi_get("data", country = NA), "country")
})

test_that("spi_get() rejects country = NA_character_ (P1.2)", {
  expect_error(spi_get("data", country = NA_character_), "country")
})

test_that("spi_get() rejects region = NA in aggregates (P1.2)", {
  expect_error(spi_get("aggregates", region = NA_character_), "region")
})

test_that("spi_get() rejects non-character country (P1.2)", {
  expect_error(spi_get("data", country = 123L), "country")
})

# ---------------------------------------------------------------------------
# P2.1 — dimension = NA_character_ gives clear error
# ---------------------------------------------------------------------------

test_that("spi_get() rejects dimension = NA_character_ with a clear error (P2.1)", {
  expect_error(spi_get("data", dimension = NA_character_), "dimension")
})

# ---------------------------------------------------------------------------
# P1.3 — schema validation after download
# ---------------------------------------------------------------------------

mock_spi_download_bad_schema <- function(file_path, version = "master") {
  data.table::data.table(wrong_col_name = c(1.0, 2.0))
}

test_that("spi_get() errors when downloaded file is missing required columns (P1.3)", {
  local_mocked_bindings(spi_download = mock_spi_download_bad_schema)
  expect_error(spi_get("data"), "missing expected columns")
})

test_that("spi_get() error message names the missing column (P1.3)", {
  local_mocked_bindings(spi_download = mock_spi_download_bad_schema)
  err <- tryCatch(spi_get("data"), error = function(e) conditionMessage(e))
  expect_match(err, "iso3c|date", ignore.case = TRUE)
})

# ---------------------------------------------------------------------------
# P1.7 — type = "index" unit tests
# ---------------------------------------------------------------------------

test_that("spi_get('index') returns a data.table (P1.7)", {
  local_mocked_bindings(spi_download = mock_spi_download)
  result <- spi_get("index")
  expect_s3_class(result, "data.table")
})

test_that("spi_get('index') result has SPI.INDEX column (P1.7)", {
  local_mocked_bindings(spi_download = mock_spi_download)
  result <- spi_get("index")
  expect_true("SPI.INDEX" %in% names(result))
})

test_that("spi_get('index') filters rows by country (P1.7)", {
  local_mocked_bindings(spi_download = mock_spi_download)
  result <- spi_get("index", country = "NOR")
  expect_equal(nrow(result), 1L)
  expect_equal(result[["iso3c"]], "NOR")
})

test_that("spi_get('index') filters columns by pillar (P1.7)", {
  local_mocked_bindings(spi_download = mock_spi_download)
  result <- spi_get("index", pillar = 1L)
  # SPI.D1.5.POV is in mock index; SPI.D3.1.POV should be excluded
  expect_true("SPI.D1.5.POV" %in% names(result))
  expect_false("SPI.D3.1.POV" %in% names(result))
  # id columns are always preserved
  expect_true("iso3c" %in% names(result))
  expect_true("SPI.INDEX" %in% names(result))
})

# ---------------------------------------------------------------------------
# P2.11 — multi-year and empty-vector edge cases
# ---------------------------------------------------------------------------

test_that("spi_get('data') filters correctly with a multi-year vector (P2.11)", {
  local_mocked_bindings(spi_download = mock_spi_download)
  result <- spi_get("data", year = c(2023L, 2024L))
  # mock data has rows for 2024 (NOR, SWE) and 2023 (AFG, KEN)
  expect_equal(nrow(result), 4L)
  expect_true(all(result[["date"]] %in% c(2023L, 2024L)))
})

test_that("spi_get('data') with empty country vector returns 0-row data.table (P2.11)", {
  local_mocked_bindings(spi_download = mock_spi_download)
  result <- spi_get("data", country = character(0))
  expect_s3_class(result, "data.table")
  expect_equal(nrow(result), 0L)
})
