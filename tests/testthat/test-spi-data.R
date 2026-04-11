test_that("spi_get validates type argument", {
  expect_error(spi_get(type = "invalid"), "should be one of")
})

test_that("spi_get validates version argument", {
  expect_error(spi_get(version = c("v1.0", "v2.0")), "must be a single character string")
  expect_error(spi_get(version = 123), "must be a single character string")
})

test_that("spi_inventory returns data.table", {
  result <- spi_inventory()
  expect_s3_class(result, "data.table")
  expect_true(nrow(result) > 0)
})

test_that("spi_inventory filters by type", {
  result <- spi_inventory(type = "index")
  expect_true(all(result$type == "index"))
})

test_that("spi_inventory has required columns", {
  result <- spi_inventory()
  expect_true(all(c("type", "file", "version") %in% names(result)))
})
