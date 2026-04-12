---
title: "data.table S3 dispatch fails inside package namespace without @importFrom"
date: 2026-04-10
category: bugs
tags: [r, data.table, namespace, s3-dispatch, devtools, roxygen2]
symptoms: ["undefined columns selected", "[.data.frame called instead of [.data.table", "dt[keep] fails inside package function but works in global env"]
---

## Problem

`[.data.table` S3 dispatch fails silently when `data.table` is listed in
`Imports:` in `DESCRIPTION` but **not imported in `NAMESPACE`** (no `import(data.table)`
or `importFrom(data.table, ...)` directive).

The symptom: `dt[logical_vector]` inside a package function dispatches to
`[.data.frame` instead of `[.data.table`, treating the logical as a **column
selector** rather than a row selector, and producing:

```
Error in `[.data.frame`(x, i): undefined columns selected
```

The same code works correctly in the global environment (after `library()`) or
when the file is `source()`'d directly, making this bug very hard to track down.

## Root Cause

When `devtools::load_all()` sets up the package namespace (as done during
`devtools::test()`), it uses the `NAMESPACE` file's `importFrom` / `import`
directives to decide which packages to integrate. Without an explicit import
directive for `data.table`, data.table's S3 methods (including `[.data.table`)
are **not accessible** from within the package namespace during `load_all()`.

S3 dispatch for primitive generics (like `[`) from within a package namespace
can fail to find methods from packages that are not explicitly imported, even
if those packages are loaded.

Note: this only manifests with `load_all()` / during testing. An installed package
that normally runs `library(spiR)` would work correctly because the regular
`library()` path loads imports properly.

## Solution

Add `@importFrom data.table` (or `@import data.table`) to the package-level
roxygen2 block in `R/<pkgname>-package.R`:

```r
#' @importFrom data.table data.table as.data.table fread :=
"_PACKAGE"
```

Then run `devtools::document()` to regenerate NAMESPACE, which adds:

```
importFrom(data.table,":=")
importFrom(data.table,as.data.table)
importFrom(data.table,data.table)
importFrom(data.table,fread)
```

This forces data.table to be integrated into the package's import environment,
making `[.data.table` accessible during `load_all()`.

## Diagnostic Steps

1. Test the function in isolation via `source('R/file.R')` → works
2. Test via `devtools::load_all()` + `pkg:::fn(dt, ...)` → fails
3. Check `body(pkg:::fn)` — function body is correct
4. Add trace to confirm `dt` IS a data.table and has correct class
5. Reproduce with `dt[c(TRUE, FALSE)]` in global env (works) vs inside
   package function with `environment(fn) <- asNamespace("pkg")` (fails)
6. Check NAMESPACE file for `importFrom(data.table, ...)` — missing!

## Notes

- The roxygen2 version mismatch warning (`You have 7.2.3 but need 7.3.1`) is
  cosmetic and does not cause this bug. The missing `@importFrom` in the source
  file is the real issue.
- `@import data.table` (imports everything) also works but is less specific.
- This applies to any package where you use data.table objects with `[` but
  don't explicitly import data.table in your NAMESPACE.

## Related

- [2026-04-11-mock-imported-function-in-package-namespace.md](../testing-patterns/2026-04-11-mock-imported-function-in-package-namespace.md) — how `@importFrom` affects which namespace `local_mocked_bindings()` must target
