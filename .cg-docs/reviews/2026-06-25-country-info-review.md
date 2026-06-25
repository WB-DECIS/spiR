---
date: 2026-06-25
depth: standard
type: standard
plan: .cg-docs/plans/2026-06-25-country-info.md
findings:
  P1.1: open
  P2.1: fixed
  P2.2: open
  P3.1: fixed
  P3.2: fixed
---

## Review Report

**Review mode**: standard
**Files reviewed**: 6
**Findings**: 5 (P0: 0, P1: 1, P2: 2, P3: 2)

### P0 — BLOCKING (immediate remediation required)

None.

### P1 — CRITICAL (must fix before merge)

- **[P1.1]** [cg-data-quality] R/spi-wrappers.R:206 — `country_info()` validates required column names, but it does not validate the country-year key its contract relies on.
  **Why**: If upstream `SPI_data.csv` ever contains duplicate `iso3c`/`date` rows while keeping the expected metadata columns, the wrapper will silently return duplicated country-year records. That breaks the documented one-row-per-country-year contract and can multiply downstream joins without any explicit failure.
  **Fix**: After selecting the required columns, assert uniqueness on `iso3c` + `date` and abort with the offending keys if duplicates are present.

### P2 — IMPORTANT (should fix)

- **[P2.1]** [cg-documentation] README.md:25 — `country_info()` is exported and documented, but it is missing from the README package surface.
  **Why**: The overview, Quick Start, Data Types table, and filtering summary still present only the older wrappers. That makes the new public API hard to discover from the package entry point.
  **Fix**: Add `country_info()` to the overview/Quick Start/Data Types sections and reflect that `country` also applies to the metadata wrapper.

- **[P2.2]** [cg-version-control] NAMESPACE:3 — the latest feature commit is not an atomic country_info change.
  **Why**: The commit also bundles unrelated generated man-page churn (`man/spi_get.Rd`, `man/spiR-package.Rd`, `man/filter_rows_by_pillar_dimension.Rd`, `man/dot-spi_inv_cache_dir.Rd`, `man/spi_clear_inventory.Rd`, `man/spi_update_inventory.Rd`, `man/spi_indicator.Rd`) alongside the intended wrapper/test/docs changes. That makes review, rollback, and release notes less precise.
  **Fix**: Split unrelated generated artifacts from the country_info feature before merge, or regenerate docs from a clean tree so the feature commit only contains country_info-related source, tests, and generated docs.

### P3 — MINOR (nice to have)

- **[P3.1]** [cg-testing] tests/testthat/test-spi-wrappers.R:403 — the tests do not pin the deterministic row ordering that `country_info()` currently guarantees.
  **Why**: The suite checks column order, but it does not assert the output row sequence. A regression in the final `iso3c`/`date` sort would still pass.
  **Fix**: Feed intentionally unsorted mock rows and assert the exact `iso3c`/`date` sequence with `expect_identical()`.

- **[P3.2]** [cg-documentation] R/spi-wrappers.R:174 — the public help text under-specifies the exact output schema and stable ordering contract.
  **Why**: The implementation and tests define an exact ordered set of metadata columns, but the current `@return` text only describes broad field groups. That makes the wrapper less self-explanatory for lookup-table and join use.
  **Fix**: Expand `@return` to list the exact returned columns, keep the one-row-per-country-year note, and state that rows are returned in deterministic `iso3c`, `date` order.

### ✅ Passed

- `cg-code-quality`: `.Rbuildignore` already excludes `.cg-docs/`; no additional package-build issues found.
- `cg-reproducibility`: no new network or cache reproducibility issues found in the scoped feature.
- `cg-performance`: no blocking performance issue beyond minor wrapper-copy considerations.
- `cg-architecture`: wrapper layering remains aligned with the existing public wrapper surface.