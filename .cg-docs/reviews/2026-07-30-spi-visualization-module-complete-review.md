---
date: 2026-07-30
depth: data-risk
type: standard
plan: .cg-docs/plans/2026-07-30-spi-visualization-module-complete.md
findings:
  P0.1: open
  P1.1: fixed
  P1.2: open
  P1.3: open
  P1.4: open
  P2.1: fixed
  P2.2: fixed
  P2.3: open
  P2.4: open
  P2.5: open
---
## Review Report

**Review mode**: data-risk
**Files reviewed**: 35
**Findings**: 10 (P0: 1, P1: 4, P2: 5, P3: 0)

### P0 — BLOCKING (immediate remediation required)
- **[P0.1]** [cg-code-quality, cg-data-quality, cg-performance] [R/spi-plot-region-pillars.R](R/spi-plot-region-pillars.R#L58) — weighted regional pillar averages use the wrong denominator when some countries have missing SPI values.
  **Why**: The weighted branch computes `sum(value * population, na.rm = TRUE) / sum(population, na.rm = TRUE)`. Countries with non-missing population but missing `value` are excluded from the numerator and still counted in the denominator, biasing regional trajectories downward.
  **Fix**: Restrict both numerator and denominator to rows where both `value` and `population` are present, or compute the weighted mean on a prefiltered valid subset. Add a test with one missing `value` and nonzero population.

### P1 — CRITICAL (must fix before merge)
- **[P1.1]** [cg-code-quality, cg-reproducibility] [R/spi-plot-map.R](R/spi-plot-map.R#L49) — geometry cache schema version was written but not validated on read. [safe_auto] [fixed]
  **Why**: Old cache objects could be accepted silently after future schema changes.
  **Fix**: Compare `obj$schema_version` to `SPI_PLOT_GEO_CACHE_SCHEMA_VERSION` and invalidate mismatches.

- **[P1.2]** [cg-documentation] [R/spi-plot-map.R](R/spi-plot-map.R#L238) — public map documentation omits required optional dependencies and live network/cache behavior. [manual]
  **Why**: `spi_plot_map()` hard-fails without suggested packages and downloads boundaries from ArcGIS on cache miss, but the roxygen/man pages do not explain the required packages, first-run network dependency, or offline-after-cache behavior.
  **Fix**: Document that `ggplot2`, `wbplot`, and `sf` are required optional dependencies, `ggiraph` is additionally required when `interactive = TRUE`, boundaries are fetched from ArcGIS on cache miss, cached locally, and offline use requires a valid cache.

- **[P1.3]** [cg-reproducibility] [R/spi-plot-map.R](R/spi-plot-map.R#L57) — offline reproducibility of map plots is time-bounded by TTL-only cache invalidation. [manual]
  **Why**: Once the cache age exceeds `SPI_PLOT_GEO_CACHE_TTL_DAYS`, offline replay fails even if a usable cached geometry already exists.
  **Fix**: Separate freshness from reproducibility by using stale cache when refresh fails or when offline, or clearly document that offline replay expires after the TTL.

- **[P1.4]** [cg-data-quality] [R/spi-plot-country-vs-region.R](R/spi-plot-country-vs-region.R#L39) — regional comparator is an unweighted country mean but the function contract does not make that explicit. [manual]
  **Why**: Users may interpret the benchmark as population-representative when it is a simple average across countries.
  **Fix**: Either document the benchmark explicitly as an unweighted country mean or add a `weighted` option and corresponding population join/tests.

### P2 — IMPORTANT (should fix)
- **[P2.1]** [cg-version-control] [.Rbuildignore](.Rbuildignore#L3) — protected documentation directories were not fully excluded from package builds. [safe_auto] [fixed]
  **Why**: `^\.cg-docs$` and `^\.github$` matched only the directory names, not descendants.
  **Fix**: Expanded to `^\.cg-docs($|/)` and `^\.github($|/)`.

- **[P2.2]** [cg-testing] [tests/testthat/test-spi-plot-geo-cache.R](tests/testthat/test-spi-plot-geo-cache.R#L1) — no focused tests covered geo-cache validation paths. [safe_auto] [fixed]
  **Why**: Cache round-trip and schema mismatch invalidation were untested.
  **Fix**: Added `test-spi-plot-geo-cache.R` covering valid round-trip and schema mismatch invalidation.

- **[P2.3]** [cg-architecture] [R/spi-plot-radar.R](R/spi-plot-radar.R#L8) — `coord_radar()` is documented but not used by `spi_plot_radar()`, which currently uses `coord_polar()`. [manual]
  **Why**: This leaves a dead architectural branch and documentation for a helper that is neither exported nor used internally.
  **Fix**: Either switch `spi_plot_radar()` to use `coord_radar()`, export it deliberately, or remove the orphaned helper/docs.

- **[P2.4]** [cg-testing] [tests/testthat/test-spi-plot-functions.R](tests/testthat/test-spi-plot-functions.R#L31) — plotting tests mostly assert return class and do not verify aggregation correctness, weighting, tooltip semantics, or selection behavior. [manual]
  **Why**: A regression in weighted means, region aggregation, or highlighted-map masking could still pass while altering output values or semantics.
  **Fix**: Add assertions on computed plot data for weighted/unweighted paths, country-selection map semantics, and missing-region error branches.

- **[P2.5]** [cg-code-quality, cg-testing] [tests/testthat/test-spi-plot-helpers.R](tests/testthat/test-spi-plot-helpers.R#L45) — package-namespace mocking assumptions are brittle when tests are not run with `pkgload::load_all()`. [manual]
  **Why**: The tests use `local_mocked_bindings()` against package functions/internal helpers; this works in the current `pkgload::load_all()` flow but is not self-evident from the test files themselves.
  **Fix**: Document or centralize the required test harness, or target the `spiR` namespace explicitly in mocks where appropriate.

### ✅ Passed
- cg-performance: No additional hot-path issues beyond repeated broad data materialization and the weighted-mean bug above.
- cg-version-control: No secret or credential leakage found.
- cg-documentation: Public man pages and exports were generated consistently for the new API.
- cg-architecture: Dependency strategy via `Suggests` is generally aligned with an optional visualization module.
