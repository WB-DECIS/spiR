---
date: 2026-04-12
title: "data.table melt() returns factor variable column by default, requiring redundant as.character() coercion"
category: "performance-issues"
language: "R"
tags: [data.table, melt, reshape, factor, variable.factor, anti-pattern, vignette]
root-cause: "melt() variable.name column is factor by default; code then calls as.character() to use it as a lookup key"
severity: "P3"
---

# data.table melt() factor default anti-pattern

## Problem

When reshaping a `data.table` from wide to long with `melt()`, the `variable`
column (controlled by `variable.name`) is returned as a **factor** by default:

```r
idx_long <- melt(
  idx_pillars,
  id.vars      = c("country", "iso3c", "date"),
  measure.vars = paste0("SPI.INDEX.PIL", 1:5),
  variable.name = "pillar",
  value.name    = "score"
)

# pillar is a factor — can't use directly as named-vector lookup key
# Forces redundant coercion:
idx_long[, pillar_label := pillar_labels[as.character(pillar)]]
```

This pattern appeared **four times** in the same vignette. Each occurrence:
1. Allocates an intermediate factor object.
2. Calls `as.character()` to create a second allocation.
3. Uses the character result as a lookup key into a named vector.

## Root Cause

`data.table::melt()` defaults to `variable.factor = TRUE` for backwards
compatibility with `reshape2::melt()`. The default is rarely what you want
in a data.table workflow where the variable column is typically used as a
character lookup key or join key.

## Solution

Add `variable.factor = FALSE` to every `melt()` call. This returns the
`variable` column as character directly, eliminating both the factor allocation
and the `as.character()` call:

```r
idx_long <- melt(
  idx_pillars,
  id.vars         = c("country", "iso3c", "date"),
  measure.vars    = paste0("SPI.INDEX.PIL", 1:5),
  variable.name   = "pillar",
  value.name      = "score",
  variable.factor = FALSE   # <-- always include this
)

# Now pillar is character — direct lookup works
idx_long[, pillar_label := pillar_labels[pillar]]
```

Also: when extracting a suffix from the variable name, prefer
`sub(fixed = TRUE)` over `gsub()` (no regex on a literal string, stops at
first match):

```r
# Anti-pattern
idx_long[, label := paste("Pillar", gsub("SPI.INDEX.PIL", "", pillar))]

# Correct
idx_long[, label := paste("Pillar", sub("SPI.INDEX.PIL", "", pillar, fixed = TRUE))]
```

**Pre-melt column subsetting is also unnecessary** when `id.vars` and
`measure.vars` are both specified — `melt()` drops unused columns internally:

```r
# Redundant — creates a full copy before melt
idx_pillars <- idx[, ..pillar_cols]
idx_long    <- melt(idx_pillars, ...)

# Idiomatic — pass the full table
idx_long <- melt(idx, id.vars = c("country", "iso3c", "date"),
                 measure.vars = pillar_cols, ..., variable.factor = FALSE)
```

## Prevention

- **Always** include `variable.factor = FALSE` in `melt()`. Consider it a
  mandatory argument in any data.table project.
- Code review checklist item: `grep -n "melt(" R/*.R vignettes/*.Rmd` and
  verify each call includes `variable.factor = FALSE`.
- When labelling reshaped columns, use a named character vector with direct
  `[ ]` indexing — no `as.character()` needed if `variable.factor = FALSE`.

## Related

- [`data.table::melt` documentation](https://rdatatable.gitlab.io/data.table/reference/melt.data.table.html)
- `vignettes/spi-data-workflows.Rmd` — four occurrences fixed in the v0.1.0 review
