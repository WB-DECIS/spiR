---
date: 2026-08-03
title: "Harden spiR visualization helpers by separating data correctness from presentation and eliminating brittle external styling"
category: "bugs"
language: "R"
tags: [visualization, ggplot2, sf, ggiraph, wbplot, spi-aggregates, map, radar, testthat, cache]
root-cause: "The visualization port mixed prototype assumptions (regional means from country data, hard dependency on non-CRAN wbplot, sf/data.table mutation patterns, and stateful package cache in tests) with public package code, causing incorrect regional comparators, brittle rendering, and non-deterministic checks."
severity: "P1"
---

# Harden spiR visualization helpers by separating data correctness from presentation and eliminating brittle external styling

## Problem

The `spi_plot_*()` visualization layer worked as a prototype, but several
production issues surfaced once it was exercised as a package API:

- Region-based plots (`spi_plot_country_vs_region()`, `spi_plot_radar()`,
  `spi_plot_regions()`, `spi_plot_region_pillars()`) were conceptually tied to
  country-level computations, even though SPI already publishes official
  regional aggregates.
- Chart styling depended on `wbplot`, which is not on CRAN and was broken in
  the local environment (`WBPALETTES`/lazy data did not load correctly).
- The map path was brittle: GDAL/TLS failures, incorrect ArcGIS layer choice,
  and invalid `data.table :=` mutation on `sf` objects.
- Tests were not fully deterministic because `spi_download()` uses an
  in-session cache that could leak state across test files.
- The radar chart lost readability after the first refactor: raw pillar labels,
  generic palette logic, and `coord_polar()` produced a result that was less
  clear than the original prototype.

## Root Cause

The original visualization drafts were appropriate as standalone prototypes but
not yet separated into three concerns that package code needs to keep distinct:

1. **Data correctness**: public visualizations must use the same published SPI
   aggregates users see elsewhere, not ad hoc recomputation from country rows.
2. **Presentation**: World Bank styling should be reproducible from the package
   itself instead of relying on an external, non-CRAN package.
3. **Execution environment**: package tests and map rendering must tolerate the
   realities of `sf`, ArcGIS, caches, and mocked downloads.

Because those concerns were still entangled, the first package version had a
combination of correctness bugs, dependency brittleness, and check-time test
instability.

## Solution

### 1. Route regional comparators through official SPI aggregates

Add a dedicated helper that normalizes aggregate rows for plotting:

```r
.spi_plot_fetch_aggregates <- function(value_cols,
                                       version = "master",
                                       region = NULL,
                                       year = NULL) {
  src <- spi_aggregates(version = version, region = region, year = year)

  out <- src[source_id %in% value_cols, .(
    region = as.character(country),
    date = as.integer(date),
    source_id = as.character(source_id),
    value = suppressWarnings(as.numeric(value))
  )]

  out[, value := data.table::fifelse(value == -99, NA_real_, value)]
  data.table::setorder(out, region, source_id, date)
  out
}
```

Then use it in the region-facing plot functions instead of recomputing means
from country rows.

### 2. Replace `wbplot` with internal World Bank style helpers

Move the style guide colours and theme into package code so plots are stable
without a GitHub-only dependency:

```r
SPI_WB_CAT <- c(
  "#34A7F2", "#FF9800", "#664AB6", "#4EC2C0", "#F3578E",
  "#081079", "#0C7C68", "#AA0000", "#DDDA21"
)

SPI_WB_SEQ <- c("#FDF6DB", "#A1CBCF", "#5D99C2", "#2868A0", "#023B6F")

.spi_scale_fill_wb_c <- function(na.value = "#CED4DE", ...) {
  ggplot2::scale_fill_gradientn(colours = SPI_WB_SEQ, na.value = na.value, ...)
}
```

This preserves World Bank styling while removing a brittle runtime dependency.

### 3. Make the map path package-safe

The stable pattern for boundaries was:

- use the correct ArcGIS layer IDs,
- download GeoJSON via `httr2`,
- read from a local tempfile with `sf::st_read()`,
- cache the normalized geometry,
- mutate `sf` objects with `$<-`, not `:=`.

```r
resp <- httr2::request(url) |>
  httr2::req_perform()
writeBin(httr2::resp_body_raw(resp), tmp)
geo_sf <- sf::st_read(tmp, quiet = TRUE)

map_sf$highlighted <- if (is.null(sel)) TRUE else map_sf$iso3 %in% sel
map_sf$value_plot <- if (!is.null(sel) && !isTRUE(zoom)) {
  data.table::fifelse(map_sf$highlighted, map_sf$value, NA_real_)
} else {
  map_sf$value
}
```

### 4. Restore radar readability without giving up official aggregates

Keep the official aggregate series, but restore the clearer original visual
form: `coord_radar()`, short pillar labels, explicit country/reference colours,
and a subtitle that explains the benchmark.

### 5. Isolate stateful tests

`spi_download()` caches by `(version, file_path)`, so tests that mock
downloads must clear that cache explicitly:

```r
setup({
  spi_clear_cache()
})

teardown({
  spi_clear_cache()
})
```

Also ensure mocks for file-path routing check the aggregates path before the
broader `SPI_data` substring.

## Prevention

- When the SPI project publishes an official aggregate, use it directly for
  public regional comparators instead of recomputing values from country rows.
- Keep package styling self-contained when a dependency is optional, non-CRAN,
  or environment-sensitive.
- Never use `:=` directly on `sf` objects; convert deliberately or use `$<-`.
- Treat caches as part of the test harness: clear them at file boundaries when
  mocking download paths.
- Preserve a successful prototype's presentation only after separating it from
  data logic; correctness and readability should evolve independently.

## Related

- `.cg-docs/brainstorms/2026-07-29-viz-ggplot-wb-guidelines-port.md` — original visualization port design that this implementation finalizes and partially corrects (`wbplot` dependency decision).
- `.cg-docs/plans/2026-07-30-spi-visualization-module-complete.md` — implementation plan for the visualization module.
- `.cg-docs/reviews/2026-07-30-spi-visualization-module-complete-review.md` — review findings that motivated several of these hardening fixes.
- `.cg-docs/solutions/testing-patterns/2026-04-11-mock-imported-function-in-package-namespace.md` — relevant test harness rule for mocking imported/package-bound functions.
- `.cg-docs/solutions/bugs/2026-04-10-datatable-s3-dispatch-fails-without-namespace-import.md` — related namespace/data.table behavior under package loading.