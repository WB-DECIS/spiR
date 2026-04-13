---
date: 2026-04-12
title: "Case-sensitive ISO3C filter silently returns 0 rows when user passes lowercase codes"
category: "data-quality"
language: "R"
tags: [iso3c, country-codes, filter, data.table, input-validation, case-sensitivity, silent-failure]
root-cause: "data.table %in% filter is case-sensitive; lowercase 'nor' does not match stored 'NOR'"
severity: "P2"
---

# Case-sensitive ISO3C filter silently returns 0 rows

## Problem

A user calls a data-access function with lowercase or mixed-case country codes:

```r
spi_index(country = c("nor", "swe"))  # lowercase
spi_index(country = c("Nor", "Swe"))  # mixed case
```

The function returns an empty `data.table` with 0 rows and no error or warning.
The lookup logic uses `dt[["iso3c"]] %in% country`, and the stored codes are
all uppercase (`"NOR"`, `"SWE"`), so `%in%` finds no match. This is a common
user mistake — ISO3C codes are conventionally uppercase but that convention
is not enforced at entry points.

## Root Cause

The raw data stores ISO3C codes in uppercase (`"NOR"`, `"SWE"`, `"AFG"`, …).
The `%in%` operator in R is case-sensitive. No normalization was applied to the
`country` argument before the filter:

```r
# Before fix — case-sensitive, silent 0-row result
keep <- dt[["iso3c"]] %in% country
dt <- dt[keep]
```

The only validation checked that `country` was a character vector with no NAs —
it did not normalize case.

## Solution

Normalize `country` to uppercase immediately after the type/NA validation,
before any filter is applied:

```r
if (!is.null(country)) {
  if (!is.character(country) || anyNA(country))
    cli::cli_abort("{.arg country} must be a character vector with no NA values.")
  country <- toupper(trimws(country))   # <-- normalize
}
```

Add `trimws()` too: it strips accidental leading/trailing whitespace that
would also cause silent mismatches.

Document the normalization in the `@param` so users know it is case-insensitive:

```r
#' @param country Character vector of ISO 3166-1 alpha-3 country codes (e.g.
#'   `c("NOR", "SWE")`). Case-insensitive; codes are coerced to uppercase
#'   automatically. `NULL` returns all countries.
```

## Prevention

- **Normalize at the boundary**: always apply `toupper(trimws())` to any
  argument that is matched against stored uppercase codes.
- Pair the normalization with a **zero-row warning** so silent empty results
  surface even when the code is correct but the filter simply matches nothing:

  ```r
  if (nrow(dt) == 0L)
    cli::cli_warn(
      "No rows matched the supplied filters. Verify country/region codes, year range, and {.arg version}."
    )
  ```

- This pattern applies to any column-lookup argument: country codes, region
  names if stored in a canonical case, version strings, etc.

## Related

- `R/spi-data.R` — where the fix was applied
- `.cg-docs/solutions/data-quality/2026-04-12-na-unsafe-reorder-setorder-on-score-columns.md` — related silent-failure pattern in sort/plot operations
