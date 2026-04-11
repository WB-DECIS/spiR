# Integration tests — require network access and hit the real GitHub repo.
# These are skipped on CRAN and when offline.

test_that("spi_data() returns a data.table with expected columns (network)", {
  skip_on_cran()
  skip_if_offline()

  result <- spi_data(year = 2024L, country = "NOR")
  expect_s3_class(result, "data.table")
  expect_true("iso3c" %in% names(result))
  expect_true("date" %in% names(result))
  expect_equal(nrow(result), 1L)
  expect_equal(result[["iso3c"]], "NOR")
})

test_that("spi_index() returns a data.table with SPI.INDEX column (network)", {
  skip_on_cran()
  skip_if_offline()

  result <- spi_index(year = 2024L, country = c("NOR", "SWE"))
  expect_s3_class(result, "data.table")
  expect_true("SPI.INDEX" %in% names(result))
  expect_equal(nrow(result), 2L)
})

test_that("spi_aggregates() returns only region rows (network)", {
  skip_on_cran()
  skip_if_offline()

  result <- spi_aggregates(year = 2024L)
  expect_s3_class(result, "data.table")
  # No individual country codes should appear
  expect_true(all(result[["iso3c"]] %in% SPI_AGGREGATE_CODES))
  # Must have core columns
  expect_true(all(c("iso3c", "country", "date", "source_id", "value") %in%
    names(result)))
})

test_that("spi_aggregates() region filter works (network)", {
  skip_on_cran()
  skip_if_offline()

  result <- spi_aggregates(
    region = "Africa Eastern and Southern",
    year   = 2024L,
    pillar = 1L
  )
  expect_true(all(result[["country"]] == "Africa Eastern and Southern"))
  expect_true(all(grepl("^SPI\\.D1\\.", result[["source_id"]])))
})

test_that("spi_versions() returns a character vector including 'master' (network)", {
  skip_on_cran()
  skip_if_offline()

  result <- spi_versions()
  expect_type(result, "character")
  expect_true("master" %in% result)
  expect_true(length(result) >= 1L)
})

test_that("spi_data() pillar column filter reduces columns (network)", {
  skip_on_cran()
  skip_if_offline()

  full    <- spi_data(year = 2024L, country = "NOR")
  pillar3 <- spi_data(year = 2024L, country = "NOR", pillar = 3L)

  expect_lt(ncol(pillar3), ncol(full))
  # All SPI/RAW indicator columns must belong to pillar 3
  indicator_cols <- names(pillar3)[grepl("^SPI\\.D[0-9]|^RAW\\.D[0-9]", names(pillar3))]
  expect_true(all(grepl("^SPI\\.D3\\.|^RAW\\.D3\\.", indicator_cols)))
})
