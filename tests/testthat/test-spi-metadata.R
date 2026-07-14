# Tests for metadata(), metadata_pillars(), and metadata_dimensions().
# Metadata is sourced via spi_download() and mocked here to avoid network calls.

make_mock_metadata <- function() {
  data.table::data.table(
    pillar = c("1", "1", "2", "2", "3"),
    pillar_name = c("Data Use", "Data Use", "Data Services", "Data Services", "Data Products"),
    pillar_description = c("P1", "P1", "P2", "P2", "P3"),
    pillar_id = c("PIL1", "PIL1", "PIL2", "PIL2", "PIL3"),
    dimension = c("1.5", "1.5", "2.1", "2.2", "3.1"),
    dimension_name = c("Poverty", "Poverty", "Standards", "Methods", "Products"),
    dimension_description = c("D15", "D15", "D21", "D22", "D31"),
    dimension_id = c("D15", "D15", "D21", "D22", "D31"),
    indicator = c("SPI.D1.5.POV", "SPI.D1.5.CHILD_MORT", "SPI.D2.1.GDDS", "SPI.D2.2.METH", "SPI.D3.1.PROD"),
    indicator_name = c("Poverty", "Child Mortality", "GDDS", "Methods", "Products"),
    indicator_description = c("I1", "I2", "I3", "I4", "I5"),
    indicator_id = c("I1", "I2", "I3", "I4", "I5"),
    indicator_scoring = c("binary", "binary", "score", "score", "score"),
    indicator_abv = c("POV", "CM", "GDDS", "METH", "PROD")
  )
}

mock_spi_download_metadata <- function(file_path, version = "master") {
  if (!identical(file_path, "01_raw_data/metadata/SPI_full_metadata.csv")) {
    stop("Unexpected path")
  }
  make_mock_metadata()
}

mock_spi_download_missing_col <- function(file_path, version = "master") {
  dt <- make_mock_metadata()
  dt[, indicator_abv := NULL]
  dt
}

mock_spi_download_failure <- function(file_path, version = "master") {
  stop("404 Not Found")
}

mock_spi_download_inconsistent_pillar_text <- function(file_path,
                                                       version = "master") {
  dt <- make_mock_metadata()
  dt <- rbind(
    dt,
    data.table::data.table(
      pillar = "2",
      pillar_name = "Data Services",
      pillar_description = "P2 (alternate description variant)",
      pillar_id = "PIL2",
      dimension = "2.1",
      dimension_name = "Standards",
      dimension_description = "D21",
      dimension_id = "D21",
      indicator = "SPI.D2.1.GDDS",
      indicator_name = "GDDS",
      indicator_description = "I3",
      indicator_id = "I3",
      indicator_scoring = "score",
      indicator_abv = "GDDS"
    )
  )
  dt
}

test_that("metadata() is exported and returns expected structure", {
  local_mocked_bindings(spi_download = mock_spi_download_metadata)
  result <- metadata(pillar = "1")
  expect_type(result, "list")
  expect_named(result, c("pillars", "dimensions", "indicators"))
  expect_s3_class(result$pillars, "data.table")
  expect_s3_class(result$dimensions, "data.table")
  expect_s3_class(result$indicators, "data.table")
  expect_true(nrow(result$pillars) > 0L)
  expect_true(nrow(result$dimensions) > 0L)
  expect_true(nrow(result$indicators) > 0L)
})

test_that("metadata() rejects non-string input and empty values", {
  local_mocked_bindings(spi_download = mock_spi_download_metadata)
  expect_error(metadata(pillar = 1), "single non-empty character")
  expect_error(metadata(dimension = 2.1), "single non-empty character")
  expect_error(metadata(indicator = NA_character_), "single non-empty character")
  expect_error(metadata(pillar = "   "), "single non-empty character")
})

test_that("metadata() validates dimension format", {
  local_mocked_bindings(spi_download = mock_spi_download_metadata)
  expect_error(metadata(dimension = "abc"), "P.D")
})

test_that("metadata() enforces hierarchy consistency for pillar and dimension", {
  local_mocked_bindings(spi_download = mock_spi_download_metadata)
  expect_error(
    metadata(pillar = "3", dimension = "2.1"),
    "belongs to pillar"
  )
})

test_that("metadata() enforces hierarchy consistency for dimension and indicator", {
  local_mocked_bindings(spi_download = mock_spi_download_metadata)
  expect_error(
    metadata(dimension = "2.2", indicator = "SPI.D2.1.GDDS"),
    "does not belong to"
  )
})

test_that("metadata() returns one warning when no match is found", {
  local_mocked_bindings(spi_download = mock_spi_download_metadata)
  expect_warning(
    result <- metadata(indicator = "SPI.D9.9.UNKNOWN"),
    "No metadata rows matched"
  )
  expect_equal(nrow(result$indicators), 0L)
})

test_that("metadata() filters by dimension correctly", {
  local_mocked_bindings(spi_download = mock_spi_download_metadata)
  result <- metadata(dimension = "2.1")
  expect_true(all(result$dimensions$dimension == "2.1"))
  expect_true(all(result$indicators$dimension == "2.1"))
  expect_equal(unique(result$pillars$pillar), "2")
})

test_that("metadata_pillars() returns pillar fields only", {
  local_mocked_bindings(spi_download = mock_spi_download_metadata)
  result <- metadata_pillars()
  expect_s3_class(result, "data.table")
  expect_identical(
    names(result),
    c("pillar", "pillar_name", "pillar_description", "pillar_id")
  )
})

test_that("metadata_pillars() returns one row per pillar key", {
  local_mocked_bindings(spi_download = mock_spi_download_inconsistent_pillar_text)
  result <- metadata_pillars()

  expect_equal(nrow(result), length(unique(result$pillar)))
  expect_equal(anyDuplicated(result$pillar), 0L)
})

test_that("metadata_dimensions() filters by pillar", {
  local_mocked_bindings(spi_download = mock_spi_download_metadata)
  result <- metadata_dimensions(pillar = "2")
  expect_s3_class(result, "data.table")
  expect_true(all(result$pillar == "2"))
})

test_that("metadata loader aborts when required columns are missing", {
  local_mocked_bindings(spi_download = mock_spi_download_missing_col)
  expect_error(
    metadata(),
    "missing required metadata columns"
  )
})

test_that("metadata loader wraps download failures with context", {
  local_mocked_bindings(spi_download = mock_spi_download_failure)
  expect_error(
    metadata(version = "SPI2099"),
    "SPI metadata"
  )
})
