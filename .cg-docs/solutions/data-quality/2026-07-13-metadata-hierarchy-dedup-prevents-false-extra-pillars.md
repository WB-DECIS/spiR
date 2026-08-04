---
date: 2026-07-13
title: "Metadata hierarchy deduplication must use stable keys, not descriptive text"
category: "data-quality"
language: "R"
tags: [metadata, hierarchy, pillars, dimensions, indicators, deduplication, data.table, upstream-variance, fail-loudly]
root-cause: "hierarchy rows were deduplicated on descriptive text fields, so small upstream text variants produced false extra rows in metadata outputs"
severity: "P2"
---

# Metadata hierarchy deduplication must use stable keys, not descriptive text

## Problem

`metadata_pillars()` surfaced an apparent sixth pillar even though the SPI
metadata source only has five pillar keys. The user-facing symptom was a shifted
hierarchy: pillar 4 looked duplicated, and the metadata that should belong to
pillar 5 appeared one position later in the output.

This is a high-confusion failure mode because the raw SPI metadata can still be
structurally valid while the package output looks corrupted.

## Root Cause

The metadata hierarchy was being deduplicated with `unique()` across the full
set of text fields:

```r
pillars <- unique(filtered[, .(
  pillar,
  pillar_name,
  pillar_description,
  pillar_id
)])
```

That logic assumes duplicate hierarchy rows are fully text-identical. In
practice, upstream metadata can contain small description variants for the same
hierarchy key. When that happens, `unique()` preserves both rows because the
text differs, even though the hierarchy key is the same.

In this case, a text variant for the same pillar key produced an extra visible
row in `metadata_pillars()`.

## Solution

Deduplicate hierarchy tables on their stable keys, not on descriptive text.
For SPI metadata, the stable keys are:

- `pillar` for pillar rows
- `pillar + dimension` for dimension rows
- `pillar + dimension + indicator` for indicator rows

A minimal fix is to collapse on those keys instead of using full-row `unique()`:

```r
pillars <- filtered[, .(
  pillar_name = pillar_name[1L],
  pillar_description = pillar_description[1L],
  pillar_id = pillar_id[1L]
), by = .(pillar)]
```

The same pattern applies to dimensions and indicators.

For a production-safe version, do not stop at key-based collapse. First verify
that each key maps to exactly one descriptive payload, then abort if upstream
metadata is ambiguous:

```r
pillar_check <- filtered[, .(
  n_name = uniqueN(pillar_name),
  n_desc = uniqueN(pillar_description),
  n_id   = uniqueN(pillar_id)
), by = .(pillar)]

bad_pillars <- pillar_check[n_name > 1L | n_desc > 1L | n_id > 1L]
if (nrow(bad_pillars) > 0L) {
  cli::cli_abort(c(
    "SPI metadata has conflicting pillar text for the same hierarchy key.",
    "x" = "Conflicting pillar keys: {.field {bad_pillars[['pillar']]}}."
  ))
}
```

That two-step pattern fixes the false extra-row symptom while keeping the
package aligned with the project rule to fail loudly on ambiguous upstream
metadata.

## Prevention

- Deduplicate hierarchical metadata with stable identifiers, never with display
  labels or descriptions.
- Treat descriptive-field disagreement inside the same hierarchy key as a data
  quality problem, not as something to silently normalize.
- Add regression tests for both cases:
  - repeated rows with identical text should collapse to one row;
  - repeated keys with conflicting text should abort.
- When reading upstream metadata, assume text fields can drift even when the
  keys remain stable.

## Related

- `R/spi-wrappers.R` — current metadata hierarchy construction
- `tests/testthat/test-spi-metadata.R` — regression coverage for metadata accessors
- `.cg-docs/reviews/2026-07-10-metadata-api-review.md` — review that surfaced the remaining fail-loudly gap
- `.cg-docs/reviews/2026-07-10-metadata-api-verify-review.md` — verify pass confirming the remaining P0/P2 follow-up
- `.cg-docs/solutions/data-quality/2026-04-12-country-code-case-sensitivity-silent-empty-filter.md` — related silent-failure prevention pattern at the API boundary
