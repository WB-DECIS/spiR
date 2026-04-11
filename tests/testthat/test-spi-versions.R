# Tests for spi_versions(). HTTP helper is mocked — no network calls.
#
# spi_versions() delegates HTTP to .spi_github_get_json(), which is
# mocked here. This keeps tests fast and stable regardless of network
# conditions.

# ---------------------------------------------------------------------------
# Mock builders
# ---------------------------------------------------------------------------

make_mock_branches <- function(...) {
  lapply(c(...), function(n) list(name = n))
}

mock_get_json_success <- function(url) {
  make_mock_branches("master", "SPI2023", "dev")
}

mock_get_json_fail <- function(url) {
  cli::cli_abort(c(
    "Failed to connect to the GitHub API.",
    "x" = "Caused by: Connection timed out",
    "i" = "URL: {url}"
  ))
}

mock_get_json_empty <- function(url) {
  list()
}

make_mock_get_json_n <- function(n) {
  function(url) lapply(seq_len(n), function(i) list(name = paste0("branch", i)))
}

# ---------------------------------------------------------------------------
# Successful response — basic behaviour
# ---------------------------------------------------------------------------

test_that("spi_versions() returns a character vector", {
  local_mocked_bindings(.spi_github_get_json = mock_get_json_success)
  result <- spi_versions()
  expect_type(result, "character")
})

test_that("spi_versions() includes 'master'", {
  local_mocked_bindings(.spi_github_get_json = mock_get_json_success)
  result <- spi_versions()
  expect_true("master" %in% result)
})

test_that("spi_versions() returns all branch names from API", {
  local_mocked_bindings(.spi_github_get_json = mock_get_json_success)
  result <- spi_versions()
  expect_setequal(result, c("master", "SPI2023", "dev"))
})

# ---------------------------------------------------------------------------
# P1.8 — "master" always present even when absent from API response
# ---------------------------------------------------------------------------

test_that("spi_versions() adds 'master' when it is absent from API response (P1.8)", {
  mock_no_master <- function(url) make_mock_branches("SPI2023", "dev")
  local_mocked_bindings(.spi_github_get_json = mock_no_master)
  result <- spi_versions()
  expect_true("master" %in% result)
})

# ---------------------------------------------------------------------------
# P3.6 — result is sorted
# ---------------------------------------------------------------------------

test_that("spi_versions() returns a sorted result (P3.6)", {
  local_mocked_bindings(.spi_github_get_json = mock_get_json_success)
  result <- spi_versions()
  expect_identical(result, sort(result))
})

# ---------------------------------------------------------------------------
# P3.2 — truncation warning at 100 branches
# ---------------------------------------------------------------------------

test_that("spi_versions() warns when API returns exactly 100 branches (P3.2)", {
  local_mocked_bindings(.spi_github_get_json = make_mock_get_json_n(100))
  expect_warning(spi_versions(), "incomplete|100")
})

test_that("spi_versions() does not warn when fewer than 100 branches", {
  local_mocked_bindings(.spi_github_get_json = make_mock_get_json_n(50))
  expect_no_warning(spi_versions())
})

# ---------------------------------------------------------------------------
# Network / API failures
# ---------------------------------------------------------------------------

test_that("spi_versions() propagates errors from .spi_github_get_json", {
  local_mocked_bindings(.spi_github_get_json = mock_get_json_fail)
  expect_error(spi_versions())
})

test_that("spi_versions() errors informatively on empty API response", {
  local_mocked_bindings(.spi_github_get_json = mock_get_json_empty)
  expect_error(spi_versions(), "parse branch names")
})
