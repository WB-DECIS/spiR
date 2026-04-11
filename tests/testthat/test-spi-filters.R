# Tests for filter helpers in R/spi-filters.R.
# All unit tests — no network calls.

# ---------------------------------------------------------------------------
# Test data constructors
# ---------------------------------------------------------------------------

make_wide_dt <- function() {
  data.table::data.table(
    iso3c            = c("NOR", "SWE", "AFG"),
    date             = c(2024L, 2024L, 2023L),
    country          = c("Norway", "Sweden", "Afghanistan"),
    # Pillar 1 indicators
    SPI.D1.5.POV     = c(1, 1, 0),
    SPI.D1.5.CHLD.MORT = c(1, 1, 1),
    RAW.D1.5.POV     = c("yes", "yes", "no"),
    # Pillar 2 indicators
    SPI.D2.1.GDDS    = c(1, 1, NA_real_),
    SPI.D2.2.Machine.readable = c(1, 1, 0),
    RAW.D2.1.GDDS    = c(1L, 1L, NA_integer_),
    # Pillar 3 indicators
    SPI.D3.1.POV     = c(1, 0.9, 0),
    RAW.D3.1.POV     = c(1, 0.9, 0),
    # Aggregate index columns (should always be preserved)
    SPI.INDEX        = c(94.1, 92.7, 30.0),
    SPI.INDEX.PIL1   = c(100, 100, 10),
    SPI.DIM1.5.INDEX = c(1, 1, 0),
    # Metadata
    region = c("Europe & Central Asia", "Europe & Central Asia", "South Asia"),
    income_level = c("High income", "High income", "Low income")
  )
}

make_long_agg_dt <- function() {
  data.table::data.table(
    iso3c      = c("AFE", "AFE", "AFE", "WLD", "WLD"),
    country    = c(
      "Africa Eastern and Southern", "Africa Eastern and Southern",
      "Africa Eastern and Southern", "World", "World"
    ),
    date       = c(2024L, 2024L, 2023L, 2024L, 2024L),
    source_id  = c(
      "SPI.D1.5.POV", "SPI.D2.1.GDDS",
      "SPI.D1.5.CHLD.MORT", "SPI.D3.1.POV", "SPI.D5.2.1.SNAU"
    ),
    value      = c(0.5, 0.8, 0.6, 0.7, 0.9)
  )
}

# ---------------------------------------------------------------------------
# is_aggregate_code()
# ---------------------------------------------------------------------------

test_that("is_aggregate_code() returns TRUE for known WB aggregate codes", {
  expect_true(is_aggregate_code("AFE"))
  expect_true(is_aggregate_code("WLD"))
  expect_true(is_aggregate_code("HIC"))
  expect_true(is_aggregate_code("SSF"))
  expect_true(is_aggregate_code("LIC"))
})

test_that("is_aggregate_code() returns FALSE for individual country codes", {
  expect_false(is_aggregate_code("NOR"))
  expect_false(is_aggregate_code("AFG"))
  expect_false(is_aggregate_code("USA"))
  expect_false(is_aggregate_code("KEN"))
})

test_that("is_aggregate_code() is vectorized", {
  result <- is_aggregate_code(c("AFE", "NOR", "WLD", "SWE"))
  expect_equal(result, c(TRUE, FALSE, TRUE, FALSE))
})

# ---------------------------------------------------------------------------
# identify_id_columns()
# ---------------------------------------------------------------------------

test_that("identify_id_columns() keeps non-indicator columns", {
  dt <- make_wide_dt()
  id_cols <- identify_id_columns(dt)
  expect_true("iso3c" %in% id_cols)
  expect_true("date" %in% id_cols)
  expect_true("country" %in% id_cols)
  expect_true("region" %in% id_cols)
  expect_true("income_level" %in% id_cols)
})

test_that("identify_id_columns() keeps SPI.INDEX aggregate columns", {
  dt <- make_wide_dt()
  id_cols <- identify_id_columns(dt)
  expect_true("SPI.INDEX" %in% id_cols)
  expect_true("SPI.INDEX.PIL1" %in% id_cols)
  expect_true("SPI.DIM1.5.INDEX" %in% id_cols)
})

test_that("identify_id_columns() excludes SPI indicator columns", {
  dt <- make_wide_dt()
  id_cols <- identify_id_columns(dt)
  expect_false("SPI.D1.5.POV" %in% id_cols)
  expect_false("RAW.D1.5.POV" %in% id_cols)
  expect_false("SPI.D3.1.POV" %in% id_cols)
})

# ---------------------------------------------------------------------------
# filter_columns_by_pillar()
# ---------------------------------------------------------------------------

test_that("filter_columns_by_pillar() returns dt unchanged when pillar is NULL", {
  dt <- make_wide_dt()
  result <- filter_columns_by_pillar(dt, NULL)
  expect_equal(names(result), names(dt))
})

test_that("filter_columns_by_pillar() keeps Pillar 1 indicator columns", {
  dt <- make_wide_dt()
  result <- filter_columns_by_pillar(dt, 1L)
  expect_true("SPI.D1.5.POV" %in% names(result))
  expect_true("SPI.D1.5.CHLD.MORT" %in% names(result))
  expect_true("RAW.D1.5.POV" %in% names(result))
})

test_that("filter_columns_by_pillar() excludes other pillar indicator columns", {
  dt <- make_wide_dt()
  result <- filter_columns_by_pillar(dt, 1L)
  expect_false("SPI.D2.1.GDDS" %in% names(result))
  expect_false("SPI.D3.1.POV" %in% names(result))
  expect_false("RAW.D2.1.GDDS" %in% names(result))
})

test_that("filter_columns_by_pillar() always preserves id columns", {
  dt <- make_wide_dt()
  result <- filter_columns_by_pillar(dt, 2L)
  expect_true("iso3c" %in% names(result))
  expect_true("date" %in% names(result))
  expect_true("SPI.INDEX" %in% names(result))
})

test_that("filter_columns_by_pillar() returns data.table", {
  dt <- make_wide_dt()
  result <- filter_columns_by_pillar(dt, 3L)
  expect_s3_class(result, "data.table")
})

# ---------------------------------------------------------------------------
# filter_columns_by_dimension()
# ---------------------------------------------------------------------------

test_that("filter_columns_by_dimension() returns dt unchanged when dimension is NULL", {
  dt <- make_wide_dt()
  result <- filter_columns_by_dimension(dt, NULL)
  expect_equal(names(result), names(dt))
})

test_that("filter_columns_by_dimension() keeps matching dimension columns", {
  dt <- make_wide_dt()
  result <- filter_columns_by_dimension(dt, "1.5")
  expect_true("SPI.D1.5.POV" %in% names(result))
  expect_true("SPI.D1.5.CHLD.MORT" %in% names(result))
  expect_true("RAW.D1.5.POV" %in% names(result))
})

test_that("filter_columns_by_dimension() excludes other dimension columns", {
  dt <- make_wide_dt()
  result <- filter_columns_by_dimension(dt, "1.5")
  expect_false("SPI.D2.1.GDDS" %in% names(result))
  expect_false("SPI.D3.1.POV" %in% names(result))
})

test_that("filter_columns_by_dimension() always preserves id columns", {
  dt <- make_wide_dt()
  result <- filter_columns_by_dimension(dt, "2.1")
  expect_true("iso3c" %in% names(result))
  expect_true("date" %in% names(result))
})

test_that("filter_columns_by_dimension() does not confuse '3.1' with '3.10'", {
  # '3.10' should NOT match pattern for '3.1'
  dt <- data.table::data.table(
    iso3c        = "NOR",
    date         = 2024L,
    SPI.D3.1.POV = 1,
    SPI.D3.10.NEQL = 0.5
  )
  result <- filter_columns_by_dimension(dt, "3.1")
  expect_true("SPI.D3.1.POV" %in% names(result))
  expect_false("SPI.D3.10.NEQL" %in% names(result))
})

# ---------------------------------------------------------------------------
# filter_rows_by_pillar_dimension() — for aggregates long format
# ---------------------------------------------------------------------------

test_that("filter_rows_by_pillar_dimension() returns dt unchanged when both NULL", {
  dt <- make_long_agg_dt()
  result <- filter_rows_by_pillar_dimension(dt, NULL, NULL)
  expect_equal(nrow(result), nrow(dt))
})

test_that("filter_rows_by_pillar_dimension() filters by pillar", {
  dt <- make_long_agg_dt()
  result <- filter_rows_by_pillar_dimension(dt, 1L, NULL)
  expect_true(all(grepl("^SPI\\.D1\\.", result[["source_id"]])))
  expect_false(any(grepl("^SPI\\.D2\\.", result[["source_id"]])))
})

test_that("filter_rows_by_pillar_dimension() filters by dimension", {
  dt <- make_long_agg_dt()
  result <- filter_rows_by_pillar_dimension(dt, NULL, "1.5")
  expect_true(all(grepl("^SPI\\.D1\\.5\\.", result[["source_id"]])))
})

test_that("filter_rows_by_pillar_dimension() dimension takes precedence over pillar", {
  dt <- make_long_agg_dt()
  # dimension "1.5" should win over pillar=2
  result <- filter_rows_by_pillar_dimension(dt, 2L, "1.5")
  expect_true(all(grepl("^SPI\\.D1\\.5\\.", result[["source_id"]])))
  expect_equal(nrow(result), sum(grepl("^SPI\\.D1\\.5\\.", dt[["source_id"]])))
})

test_that("filter_rows_by_pillar_dimension() returns data.table", {
  dt <- make_long_agg_dt()
  result <- filter_rows_by_pillar_dimension(dt, 3L, NULL)
  expect_s3_class(result, "data.table")
})

# ---------------------------------------------------------------------------
# P2.12 — pillar 4 and 5, and no-indicator edge case
# ---------------------------------------------------------------------------

test_that("filter_columns_by_pillar() handles pillar 4 correctly (P2.12)", {
  dt <- data.table::data.table(
    iso3c        = "NOR",
    date         = 2024L,
    country      = "Norway",
    SPI.D4.1.ADM = 0.8,
    SPI.D5.1.LAW = 0.9
  )
  result <- filter_columns_by_pillar(dt, 4L)
  expect_true("SPI.D4.1.ADM" %in% names(result))
  expect_false("SPI.D5.1.LAW" %in% names(result))
  expect_true("iso3c" %in% names(result))
  expect_true("date" %in% names(result))
})

test_that("filter_columns_by_pillar() handles pillar 5 correctly (P2.12)", {
  dt <- data.table::data.table(
    iso3c        = "NOR",
    date         = 2024L,
    country      = "Norway",
    SPI.D4.1.ADM = 0.8,
    SPI.D5.1.LAW = 0.9
  )
  result <- filter_columns_by_pillar(dt, 5L)
  expect_false("SPI.D4.1.ADM" %in% names(result))
  expect_true("SPI.D5.1.LAW" %in% names(result))
  expect_true("iso3c" %in% names(result))
})

test_that("filter_columns_by_pillar() returns only id columns when no indicator matches (P2.12)", {
  dt <- make_wide_dt()  # has pillars 1, 2, 3 — not 4 or 5
  id_cols <- identify_id_columns(dt)
  result <- filter_columns_by_pillar(dt, 4L)
  expect_setequal(names(result), id_cols)
})
