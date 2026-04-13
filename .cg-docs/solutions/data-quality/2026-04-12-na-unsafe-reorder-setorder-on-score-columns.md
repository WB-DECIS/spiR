---
date: 2026-04-12
title: "ggplot2 reorder() and data.table setorder() silently misbehave when the sort column contains NA"
category: "data-quality"
language: "R"
tags: [ggplot2, reorder, setorder, NA, missing-values, sorting, visualization, data.table]
root-cause: "reorder() produces a warning and undefined NA ordering; setorder() silently places NAs last"
severity: "P2"
---

# NA-unsafe reorder() and setorder() with score columns

## Problem

SPI score columns (`SPI.INDEX`, `SPI.INDEX.PIL1`–`PIL5`) are `NA` for
country-years where data is unavailable. Two common code patterns silently
misbehave when NAs are present:

### 1. ggplot2::reorder() in an aesthetics mapping

```r
ggplot(idx, aes(x = reorder(country, SPI.INDEX), y = SPI.INDEX)) +
  geom_col()
```

When `SPI.INDEX` contains `NA`:
- R raises: `Warning: NAs introduced by coercion`
- The order of `NA`-scored countries is undefined (depends on internal factor
  level assignment)
- The chart renders but with misplaced or unlabelled bars

### 2. data.table::setorder() for ranking

```r
setorder(latest_year, -SPI.INDEX)
bottom10 <- tail(latest_year, 10)
```

`setorder()` places `NA` values at the end when sorting descending. `tail()`
then includes those `NA`-scored entries as "bottom 10 performers", which is
misleading — they are countries with **no data**, not countries with low scores.

## Root Cause

Neither function errors on NAs. Their behaviour is defined but non-obvious:

- `reorder()` documentation states: "ties are broken by the original factor
  order" but does not address NAs in the sort variable. In practice, NAs cause
  a coercion warning and produce an unpredictable ordering.
- `setorder()` documentation notes NAs sort last (ascending) or last
  (descending) by default (`na.last = TRUE` is the default). This is correct
  for database semantics but wrong for "rank the worst performers" use cases
  where NA should be excluded entirely.

## Solution

**Filter NAs before any sort or reorder operation** on a score column:

```r
# Before ggplot reorder
idx <- idx[!is.na(SPI.INDEX)]
ggplot(idx, aes(x = reorder(country, SPI.INDEX), y = SPI.INDEX)) + ...
```

```r
# Before ranking
latest_year <- latest_year[!is.na(SPI.INDEX)]
setorder(latest_year, -SPI.INDEX)
top10    <- head(latest_year, 10)
bottom10 <- tail(latest_year, 10)
```

Add an explanatory comment so the intent is clear:

```r
# Exclude countries with no overall score in this year before ranking
latest_year <- latest_year[!is.na(SPI.INDEX)]
```

For the `setorder`/`tail` pattern, if you intentionally want to see all
countries including those with no data, use `na.last = TRUE` explicitly and
document it:

```r
setorder(latest_year, -SPI.INDEX, na.last = TRUE)  # NA rows at end
```

## Prevention

- Any time a score column is used in `reorder()`, `setorder()`, `rank()`, or
  `order()`, add an `!is.na()` filter first unless NAs are intentionally part
  of the output.
- When writing documentation examples that rank or sort by a score column,
  always include the NA filter — it models the correct usage for users who
  copy the example.
- Add to code review checklist: "are score columns guarded for NA before
  ranking/plotting?"

## Related

- `vignettes/spi-data-workflows.Rmd` — fixed in v0.1.0 review (F23)
- [data.table setorder documentation](https://rdatatable.gitlab.io/data.table/reference/setorder.html) — na.last parameter
- `.cg-docs/solutions/data-quality/2026-04-12-country-code-case-sensitivity-silent-empty-filter.md` — related silent-failure pattern
