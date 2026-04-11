# Tests for the internal spi_download() function.
# All tests are unit tests (no network). Network is mocked via
# local_mocked_bindings().

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

mock_download_success <- function(url, destfile, quiet, mode) {
  # Write a tiny representative CSV to the destination
  writeLines(
    c(
      'iso3c,date,SPI.D1.5.POV,country',
      '"NOR",2024,1,"Norway"',
      '"SWE",2024,1,"Sweden"'
    ),
    destfile
  )
  invisible(0L)
}

mock_download_fail <- function(url, destfile, quiet, mode) {
  stop("HTTP error 404: Not Found")
}

# ---------------------------------------------------------------------------
# Input validation
# ---------------------------------------------------------------------------

test_that("spi_download() rejects non-character version", {
  expect_error(
    spi_download("03_output_data/SPI_data.csv", version = 123),
    "`version`"
  )
})

test_that("spi_download() rejects vector version", {
  expect_error(
    spi_download("03_output_data/SPI_data.csv", version = c("master", "v2")),
    "`version`"
  )
})

test_that("spi_download() rejects empty string version", {
  expect_error(
    spi_download("03_output_data/SPI_data.csv", version = ""),
    "`version`"
  )
})

# ---------------------------------------------------------------------------
# Network error handling
# ---------------------------------------------------------------------------

test_that("spi_download() propagates a helpful error on network failure", {
  local_mocked_bindings(
    download.file = mock_download_fail,
    .package = "utils"
  )
  expect_error(
    spi_download("03_output_data/SPI_data.csv", version = "master"),
    "Failed to download"
  )
})

test_that("spi_download() error message includes URL and version", {
  local_mocked_bindings(
    download.file = mock_download_fail,
    .package = "utils"
  )
  err <- tryCatch(
    spi_download("03_output_data/SPI_data.csv", version = "bad-branch"),
    error = function(e) conditionMessage(e)
  )
  expect_match(err, "bad-branch")
  expect_match(err, "03_output_data/SPI_data.csv")
})

# ---------------------------------------------------------------------------
# Successful download
# ---------------------------------------------------------------------------

test_that("spi_download() returns a data.table on success", {
  local_mocked_bindings(
    download.file = mock_download_success,
    .package = "utils"
  )
  result <- spi_download("03_output_data/SPI_data.csv")
  expect_s3_class(result, "data.table")
})

test_that("spi_download() result has expected columns", {
  local_mocked_bindings(
    download.file = mock_download_success,
    .package = "utils"
  )
  result <- spi_download("03_output_data/SPI_data.csv")
  expect_true("iso3c" %in% names(result))
  expect_true("date" %in% names(result))
})

# ---------------------------------------------------------------------------
# P1.6 — non-zero exit status from download.file
# ---------------------------------------------------------------------------

test_that("spi_download() errors on non-zero download exit status (P1.6)", {
  spi_clear_cache()
  withr::defer(spi_clear_cache())
  mock_nonzero_exit <- function(url, destfile, quiet, mode) invisible(1L)
  local_mocked_bindings(download.file = mock_nonzero_exit, .package = "utils")
  expect_error(
    spi_download("03_output_data/SPI_data.csv", version = "nonzero-exit-p16"),
    "non-zero exit status"
  )
})

# ---------------------------------------------------------------------------
# P2.2 — warning when downloaded file has zero rows
# ---------------------------------------------------------------------------

test_that("spi_download() warns when downloaded file contains no rows (P2.2)", {
  spi_clear_cache()
  withr::defer(spi_clear_cache())
  mock_empty_csv <- function(url, destfile, quiet, mode) {
    writeLines("iso3c,date,SPI.D1.5.POV,country", destfile)
    invisible(0L)
  }
  local_mocked_bindings(download.file = mock_empty_csv, .package = "utils")
  expect_warning(
    spi_download("03_output_data/SPI_data.csv", version = "empty-test-p22"),
    "no rows"
  )
})

# ---------------------------------------------------------------------------
# P2.9 — fread parse errors give informative message
# ---------------------------------------------------------------------------

test_that("spi_download() wraps fread parse errors informatively (P2.9)", {
  spi_clear_cache()
  withr::defer(spi_clear_cache())
  local_mocked_bindings(download.file = mock_download_success, .package = "utils")
  local_mocked_bindings(
    fread = function(...) stop("input contains embedded NULs")
  )
  expect_error(
    spi_download("03_output_data/SPI_data.csv", version = "fread-fail-test"),
    "parse.*CSV|CSV.*parse",
    ignore.case = TRUE
  )
})

# ---------------------------------------------------------------------------
# P2.5 — in-session caching
# ---------------------------------------------------------------------------

test_that("spi_download() caches results; second call skips re-download (P2.5)", {
  spi_clear_cache()
  withr::defer(spi_clear_cache())

  download_count <- 0L
  counting_mock <- function(url, destfile, quiet, mode) {
    download_count <<- download_count + 1L
    writeLines(
      c('iso3c,date,SPI.D1.5.POV', '"NOR",2024,1'),
      destfile
    )
    invisible(0L)
  }
  local_mocked_bindings(download.file = counting_mock, .package = "utils")

  spi_download("03_output_data/SPI_data.csv", version = "cache-test-v1")
  spi_download("03_output_data/SPI_data.csv", version = "cache-test-v1")

  expect_equal(download_count, 1L)
})

test_that("spi_download() uses different cache entries for different versions (P2.5)", {
  spi_clear_cache()
  withr::defer(spi_clear_cache())

  download_count <- 0L
  counting_mock <- function(url, destfile, quiet, mode) {
    download_count <<- download_count + 1L
    writeLines(c('iso3c,date', '"NOR",2024'), destfile)
    invisible(0L)
  }
  local_mocked_bindings(download.file = counting_mock, .package = "utils")

  spi_download("03_output_data/SPI_data.csv", version = "cache-ver-a")
  spi_download("03_output_data/SPI_data.csv", version = "cache-ver-b")

  expect_equal(download_count, 2L)
})
