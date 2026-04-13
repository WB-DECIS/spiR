---
date: 2026-04-12
title: "renv::snapshot() cascades to hundreds of uninstalled Suggests when package.dependency.fields includes 'Suggests'"
category: "environment-issues"
language: "R"
tags: [renv, renv.lock, snapshot, Suggests, lockfile, package-development]
root-cause: "renv follows Suggests of every package in the dependency graph, not just the project's own Suggests"
severity: "P2"
---

# renv::snapshot() Suggests cascade failure

## Problem

After adding `"Suggests"` to `package.dependency.fields` in `renv/settings.json`
to capture an R package's own Suggests dependencies (e.g. `testthat`, `knitr`,
`ggplot2`), `renv::snapshot()` aborts with:

```
The following required packages are not installed:
- bench           [required by httr2]
- BiocManager     [required by renv]
- bit             [required by data.table]
...60+ more...
Error: aborting snapshot due to pre-flight validation failure
```

The intent was to lock the 4–5 packages listed in `Suggests:` of `DESCRIPTION`.
Instead, renv followed the `Suggests` field of every package in the dependency
graph (`httr2`, `data.table`, `cli`, `glue`, …), requiring hundreds of packages
that are not installed.

## Root Cause

`package.dependency.fields` controls which DESCRIPTION fields renv traverses
for **all** packages in the graph, not just the root package. Setting it to
include `"Suggests"` tells renv: "for every package I encounter, also install
everything that package Suggests." This creates an exponential cascade.

The `renv` documentation notes this but the implication for package development
(as opposed to application development) is easy to miss.

## Solution

**Do not add `"Suggests"` to `package.dependency.fields`.** Leave the setting
at its default:

```json
"package.dependency.fields": [
  "Imports",
  "Depends",
  "LinkingTo"
]
```

Instead, add the project's own Suggests to `renv.lock` directly using
`renv::record()` with the simple `list(name = "version")` syntax:

```r
renv::record(list(
  testthat  = "3.3.2",
  knitr     = "1.50",
  rmarkdown = "2.29",
  ggplot2   = "3.5.2",
  withr     = "3.0.2"
))
```

This writes the entries directly into `renv.lock` without triggering validation
or installing anything. It records the versions that are already installed in
the system/user library.

Confirm the versions to record with:

```r
pkgs <- c("testthat", "knitr", "rmarkdown", "ggplot2", "withr")
for (p in pkgs) cat(p, as.character(packageVersion(p)), "\n")
```

## Prevention

- Never set `"Suggests"` in `package.dependency.fields` for R **packages**.
  It is only appropriate for R **applications** (Shiny apps, plumber APIs, etc.)
  where you want to pin the full test dependency graph.
- To lock a package's own Suggests, use `renv::record()` with explicit
  name–version pairs after `renv::install()` or after confirming the packages
  are installed.
- Document this convention in the project's `renv/settings.json` or README so
  future contributors don't re-add `"Suggests"`.

## Related

- [renv IDs for uninstalled Suggests (renv docs)](https://rstudio.github.io/renv/articles/faq.html)
- `.cg-docs/solutions/environment-issues/2026-04-11-renv-lock-ini-format-breaks-all-renv-operations.md`
