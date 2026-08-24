# Tests for metadata(), metadata_pillars(), and metadata_dimensions().
# Metadata is sourced via spi_download() and mocked here to avoid network calls.

make_mock_metadata <- function() {
  data.table::data.table(
    pillar = c("1", "1", "2", "2", "3"),
    pillar_name = c("Data Use", "Data Use", "Data Services", "Data Services", "Data Products"),
    pillar_description = c("P1", "P1", "P2", "P2", "P3"),
    pillar_id = c("SPI.INDEX.PIL1", "SPI.INDEX.PIL1", "SPI.INDEX.PIL2", "SPI.INDEX.PIL2", "SPI.INDEX.PIL3"),
    dimension = c("5", "5", "1", "2", "1"),
    dimension_name = c("Poverty", "Poverty", "Standards", "Methods", "Products"),
    dimension_description = c("D15", "D15", "D21", "D22", "D31"),
    dimension_id = c("SPI.DIM1.5.INDEX", "SPI.DIM1.5.INDEX", "SPI.DIM2.1.INDEX", "SPI.DIM2.2.INDEX", "SPI.DIM3.1.INDEX"),
    indicator = c("1", "2", "1", "1", "1"),
    indicator_name = c("Poverty", "Child Mortality", "GDDS", "Methods", "Products"),
    indicator_description = c("I1", "I2", "I3", "I4", "I5"),
    indicator_id = c("SPI.D1.5.POV", "SPI.D1.5.CHILD_MORT", "SPI.D2.1.GDDS", "SPI.D2.2.METH", "SPI.D3.1.PROD"),
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
      pillar_id = "SPI.INDEX.PIL2",
      dimension = "1",
      dimension_name = "Standards",
      dimension_description = "D21",
      dimension_id = "SPI.DIM2.1.INDEX",
      indicator = "1",
      indicator_name = "GDDS",
      indicator_description = "I3",
      indicator_id = "SPI.D2.1.GDDS",
      indicator_scoring = "score",
      indicator_abv = "GDDS"
    )
  )
  dt
}

mock_spi_download_duplicate_pillar_row <- function(file_path,
                                                   version = "master") {
  dt <- make_mock_metadata()
  duplicate_row <- dt[dt$pillar == "2" & dt$dimension == "1"][1L]
  rbind(dt, duplicate_row)
}

mock_spi_download_empty_indicator_keys <- function(file_path,
                                                    version = "master") {
  dt <- make_mock_metadata()
  dt[, indicator := NA_character_]
  dt[, indicator_id := ""]
  dt
}

mock_spi_download_conflicting_headers <- function(file_path,
                                                  version = "master") {
  dt <- make_mock_metadata()
  dt[, extra_pillar := pillar]
  data.table::setnames(dt, "extra_pillar", "Pillar")
  dt
}

mock_spi_download_spaced_headers <- function(file_path,
                                              version = "master") {
  dt <- make_mock_metadata()
  data.table::setnames(
    dt,
    old = c("pillar_name", "dimension_id", "indicator_abv"),
    new = c("Pillar Name", "dimension-id", "indicator abv")
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
  expect_error(metadata(dimension = "abc"), "canonical dimension value")
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

test_that("metadata() accepts SPI pillar and dimension IDs", {
  local_mocked_bindings(spi_download = mock_spi_download_metadata)
  result <- metadata(
    pillar = "SPI.INDEX.PIL2",
    dimension = "SPI.DIM2.1.INDEX"
  )

  expect_equal(unique(result$pillars$pillar), "2")
  expect_equal(unique(result$dimensions$dimension), "2.1")
  expect_equal(unique(result$dimensions$dimension_id), "SPI.DIM2.1.INDEX")
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
  local_mocked_bindings(spi_download = mock_spi_download_duplicate_pillar_row)
  result <- metadata_pillars()

  expect_equal(nrow(result), length(unique(result$pillar)))
  expect_equal(anyDuplicated(result$pillar), 0L)
})

test_that("metadata() does not return placeholder indicators", {
  local_mocked_bindings(spi_download = mock_spi_download_empty_indicator_keys)
  expect_warning(
    result <- metadata(),
    "No metadata rows matched"
  )

  expect_false(anyNA(result$indicators$indicator))
  expect_equal(nrow(result$indicators), 0L)
})

test_that("metadata() rejects conflicting hierarchy metadata", {
  local_mocked_bindings(spi_download = mock_spi_download_inconsistent_pillar_text)

  expect_error(
    metadata_pillars(),
    "conflicting|ambiguous",
    ignore.case = TRUE
  )
})

test_that("metadata_dimensions() filters by pillar", {
  local_mocked_bindings(spi_download = mock_spi_download_metadata)
  result <- metadata_dimensions(pillar = "2")
  expect_s3_class(result, "data.table")
  expect_true(all(result$pillar == "2"))
})

test_that("metadata_dimensions() accepts SPI pillar IDs", {
  local_mocked_bindings(spi_download = mock_spi_download_metadata)
  result <- metadata_dimensions(pillar = "SPI.INDEX.PIL2")
  expect_s3_class(result, "data.table")
  expect_true(all(result$pillar == "2"))
})

test_that("metadata_indicators() returns indicator table", {
  local_mocked_bindings(spi_download = mock_spi_download_metadata)
  result <- metadata_indicators()
  expect_s3_class(result, "data.table")
  expect_true(all(c(
    "pillar", "dimension", "indicator", "indicator_name",
    "indicator_description", "indicator_id", "indicator_scoring",
    "indicator_abv"
  ) %in% names(result)))
})

test_that("metadata_indicators() honors pillar, dimension, and indicator", {
  local_mocked_bindings(spi_download = mock_spi_download_metadata)

  by_pillar <- metadata_indicators(pillar = "2")
  expect_true(all(by_pillar$pillar == "2"))

  by_dimension <- metadata_indicators(dimension = "2.1")
  expect_true(all(by_dimension$dimension == "2.1"))

  by_indicator <- metadata_indicators(indicator = "SPI.D2.1.GDDS")
  expect_equal(unique(by_indicator$indicator), "SPI.D2.1.GDDS")
})

test_that("metadata_indicators() forwards arguments to metadata()", {
  call_log <- NULL

  mock_metadata <- function(pillar = NULL,
                            dimension = NULL,
                            indicator = NULL,
                            version = "master") {
    call_log <<- list(
      pillar = pillar,
      dimension = dimension,
      indicator = indicator,
      version = version
    )

    list(
      pillars = data.table::data.table(),
      dimensions = data.table::data.table(),
      indicators = data.table::data.table(indicator = "SPI.D2.1.GDDS")
    )
  }

  local_mocked_bindings(metadata = mock_metadata)
  result <- metadata_indicators(
    pillar = "2",
    dimension = "2.1",
    indicator = "SPI.D2.1.GDDS",
    version = "SPI2023"
  )

  expect_s3_class(result, "data.table")
  expect_equal(call_log$pillar, "2")
  expect_equal(call_log$dimension, "2.1")
  expect_equal(call_log$indicator, "SPI.D2.1.GDDS")
  expect_equal(call_log$version, "SPI2023")
})

test_that("metadata loader aborts when required columns are missing", {
  local_mocked_bindings(spi_download = mock_spi_download_missing_col)
  expect_error(
    metadata(),
    "missing required metadata columns"
  )
})

test_that("metadata loader normalizes spaced and punctuated headers", {
  local_mocked_bindings(spi_download = mock_spi_download_spaced_headers)
  result <- metadata()

  expect_s3_class(result$indicators, "data.table")
  expect_true(all(c("pillar_name", "dimension_id", "indicator_abv") %in%
    names(result$indicators)))
})

test_that("metadata loader rejects normalized header collisions", {
  local_mocked_bindings(spi_download = mock_spi_download_conflicting_headers)
  expect_error(
    metadata(),
    "ambiguous column names"
  )
})

test_that("metadata loader wraps download failures with context", {
  local_mocked_bindings(spi_download = mock_spi_download_failure)
  expect_error(
    metadata(version = "SPI2099"),
    "SPI metadata"
  )
})
