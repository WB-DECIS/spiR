---
date: 2026-04-11
title: "Mock a package-private .function() helper to test functions that delegate HTTP"
category: "testing-patterns"
language: "R"
tags: [testthat, local_mocked_bindings, mocking, httr2, internal-functions, http, spi_versions]
root-cause: "When spi_versions() used readLines() directly, tests mocked base::readLines. After migrating to httr2, the old mocks broke. Extracting a thin .spi_github_get_json() helper gave tests a single, stable mock target regardless of the underlying HTTP library."
severity: "P2"
---

# Mock a package-private helper to test functions that delegate HTTP

## Problem

`spi_versions()` originally called `readLines(url)` to fetch JSON from the
GitHub API and parsed it with regex. Tests mocked `base::readLines`:

```r
# OLD — fragile: tied to readLines implementation detail
local_mocked_bindings(readLines = mock_readlines_success, .package = "base")
```

After migrating to httr2 for proper User-Agent headers and structured error
handling, all tests for `spi_versions()` broke because `base::readLines` was
no longer called.

## Root Cause

The tests were mocking an *implementation detail* (which HTTP primitive the
function used) rather than the *behaviour contract* (what JSON data the GitHub
API should return). When the implementation changed, every test had to be
rewritten.

## Solution

Extract a thin internal helper that is the single HTTP touchpoint — easy
to mock without caring about the underlying library:

```r
# R/spi-github.R — internal helper (the only thing tests need to mock)
.spi_github_get_json <- function(url) {
  resp <- httr2::request(url) |>
    httr2::req_headers("User-Agent" = "spiR R package (...)") |>
    httr2::req_error(is_error = \(r) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) != 200L)
    cli::cli_abort(c("GitHub API returned an error.", ...))

  httr2::resp_body_json(resp)
}

# spi_versions() calls only .spi_github_get_json(), nothing else
spi_versions <- function() {
  branches <- .spi_github_get_json(url)
  branch_names <- vapply(branches, `[[`, character(1L), "name")
  sort(union(branch_names, "master"))
}
```

Tests mock only `.spi_github_get_json()` — no `.package` needed:

```r
# tests/testthat/test-spi-versions.R

# Build mock response objects
make_mock_branches <- function(...) {
  lapply(c(...), function(n) list(name = n))
}

mock_get_json_success <- function(url) {
  make_mock_branches("master", "SPI2023", "dev")
}

test_that("spi_versions() returns sorted branches", {
  local_mocked_bindings(.spi_github_get_json = mock_get_json_success)
  expect_identical(spi_versions(), sort(spi_versions()))
})

# P1.8: master always present
test_that("spi_versions() adds 'master' when absent from API", {
  mock_no_master <- function(url) make_mock_branches("SPI2023", "dev")
  local_mocked_bindings(.spi_github_get_json = mock_no_master)
  expect_true("master" %in% spi_versions())
})
```

## Prevention

When writing a function that calls an external API or network resource:

1. **Extract a named internal helper** (e.g. `.pkg_http_get()`) that is the
   *only* place the HTTP library is used.
2. **Mock only that helper** in tests — not the HTTP library primitives.
3. Keep the helper thin: request → error check → return parsed body. No
   business logic.

This pattern means switching HTTP libraries (e.g. httr → httr2 → curl) never
requires rewriting tests — only the helper changes.

## Related

- [2026-04-11-mock-imported-function-in-package-namespace.md](2026-04-11-mock-imported-function-in-package-namespace.md) — `.package` argument rules for `local_mocked_bindings()`
