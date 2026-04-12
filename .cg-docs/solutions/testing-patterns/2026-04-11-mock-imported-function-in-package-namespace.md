---
date: 2026-04-11
title: "Mock an imported function in the package's own namespace, not the source package"
category: "testing-patterns"
language: "R"
tags: [testthat, local_mocked_bindings, mocking, fread, data.table, importFrom, namespace]
root-cause: "local_mocked_bindings() patches the binding in the package where the function is *called*, not where it is *defined*. Using .package = 'data.table' patches data.table's namespace, which is never reached when spiR calls a locally-bound fread."
severity: "P2"
---

# Mock an imported function in the package's own namespace, not the source package

## Problem

A test tried to mock `fread` to make it throw an error, but the mock had no
effect and the real `fread` ran instead:

```r
# WRONG — patches data.table's namespace, not spiR's
local_mocked_bindings(
  fread = function(...) stop("parse error"),
  .package = "data.table"
)
spi_download(...)  # real fread still runs; test fails
```

The test was checking that `spi_download()` wraps fread parse errors with a
helpful `cli_abort()` message.

## Root Cause

`local_mocked_bindings()` (testthat 3 edition) patches the binding of the
named symbol in the calling environment or in the `.package` namespace.

When `spiR` uses `@importFrom data.table fread`, R copies the binding for
`fread` into *spiR's own namespace*. Any call to `fread` inside `spi_download()`
resolves via spiR's namespace, **not** via `data.table`'s namespace. Patching
`data.table:::fread` has no effect on the copy already bound in `spiR`.

Critically, this only works because the production code calls the *unqualified*
`fread(...)` (relying on `@importFrom`), NOT the qualified
`data.table::fread(...)`. A qualified call **always** routes through `data.table`
and cannot be mocked via the importing package's namespace.

## Solution

Omit `.package` entirely (defaults to the test's package, i.e. `spiR`):

```r
# CORRECT — patches the fread binding inside spiR's namespace
local_mocked_bindings(
  fread = function(...) stop("input contains embedded NULs")
)
expect_error(
  spi_download("03_output_data/SPI_data.csv", version = "fread-fail-test"),
  "parse.*CSV",
  ignore.case = TRUE
)
```

And ensure production code uses the unqualified form:

```r
# R/spi-download.R — CORRECT (mockable)
dt <- tryCatch(
  fread(tmp, data.table = TRUE, encoding = "UTF-8"),
  error = function(e) cli::cli_abort(...)
)

# R/spi-download.R — WRONG (cannot be mocked via spiR namespace)
dt <- data.table::fread(tmp, ...)
```

## Prevention

- Always use unqualified `fread(...)` (not `data.table::fread(...)`) when the
  call needs to be mockable in tests.
- Only add `data.table::` prefix when *not* importing the function (i.e., no
  `@importFrom data.table fread`), or in examples/vignettes that run outside the
  package namespace.
- The same rule applies to any `@importFrom` function: `cli::cli_abort()` inside
  the package is fine (cli functions aren't typically mocked), but anything you
  plan to mock should be called unqualified.

## Related

- [2026-04-10-datatable-s3-dispatch-fails-without-namespace-import.md](../bugs/2026-04-10-datatable-s3-dispatch-fails-without-namespace-import.md) — related namespace import issue
- testthat docs: `?testthat::local_mocked_bindings`
