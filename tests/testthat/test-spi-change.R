test_that("spi_change calculates changes over available years", {
  data <- data.table::data.table(
    iso3c = c("AAA", "AAA", "AAA", "BBB"),
    date = c(2016L, 2018L, 2020L, 2020L),
    SPI.INDEX = c(50, 60, 75, 80)
  )

  result <- spi_change(data)

  expect_equal(result$change_previous[1:3], c(NA, 10, 15))
  expect_equal(result$change_first[1:3], c(0, 10, 25))
  expect_true(is.na(result$change_previous[[4L]]))
  expect_equal(result$change_first[[4L]], 0)
  expect_equal(names(data), c("iso3c", "date", "SPI.INDEX"))
})

test_that("spi_change preserves missing scores and supports custom grouping", {
  data <- data.table::data.table(
    country = c("AAA", "AAA", "AAA"),
    year = c(2020L, 2021L, 2022L),
    score = c(40, NA, 55)
  )

  result <- spi_change(
    data,
    value_col = "score",
    group_cols = "country",
    year_col = "year"
  )

  expect_true(is.na(result$change_previous[[2L]]))
  expect_true(is.na(result$change_first[[2L]]))
  expect_equal(result$change_previous[[3L]], 15)
  expect_equal(result$change_first[[3L]], 15)
})

test_that("spi_change validates required arguments", {
  expect_error(spi_change(data.frame()), "missing required columns")
  expect_error(
    spi_change(data.frame(x = 1), value_col = "x"),
    "missing required columns"
  )
  expect_error(
    spi_change(data.frame(x = 1), group_cols = character()),
    "non-empty character vector"
  )
})