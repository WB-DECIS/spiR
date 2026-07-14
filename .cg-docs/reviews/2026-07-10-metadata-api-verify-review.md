---
date: 2026-07-13
depth: light
parent-review: .cg-docs/reviews/2026-07-10-metadata-api-review.md
type: verification
findings:
  P0.1: open
  P1.1: open
  P2.1: open
  P3.1: open
---

## Review Report

**Review mode**: light
**Files reviewed**: 12
**Findings**: 4 (P0: 1, P1: 1, P2: 1, P3: 1)

### P0 — BLOCKING (immediate remediation required)
- **[P0.1]** [cg-code-quality/cg-testing] R/spi-wrappers.R:438 — metadata deduplication still silently resolves conflicting hierarchy text by taking the first row per key.
  **Why**: The pillar, dimension, and indicator summaries still use first-row selection instead of validating uniqueness. If upstream ships conflicting names, descriptions, or IDs for the same key, the package returns an arbitrary variant based on row order rather than failing loudly.
  **Fix**: Validate that each hierarchy key maps to exactly one distinct descriptive payload before collapsing; abort with a clear `cli::cli_abort()` when conflicts exist, and update the regression test to expect that error.

### P1 — CRITICAL (must fix before merge)
- **[P1.1]** [cg-code-quality/cg-testing] .cg-docs/active-state/current.json:3 — workflow state is still rewound to the older country-info task while the metadata API plan remains active.
  **Why**: `current.json` still references the completed 2026-06-25 plan/work-report even though the metadata API plan remains the active work item. That is cross-file breakage in protected workflow state and corrupts the evidence trail for this task.
  **Fix**: Restore or regenerate `current.json` so it references the active metadata plan and matching execution report.

### P2 — IMPORTANT (should fix)
- **[P2.1]** [cg-code-quality/cg-testing] R/spi-data.R:52 — header-normalization and normalized-name collision handling in `.spi_read_metadata()` is still untested.
  **Why**: The loader now normalizes upstream headers and aborts on normalized-name collisions, but `tests/testthat/test-spi-metadata.R` still only covers missing-column and download-failure paths. A future upstream header change could therefore break every metadata accessor without a targeted regression test.
  **Fix**: Add one success test for spaced/punctuated headers normalizing correctly and one failure test where two raw headers normalize to the same name and `metadata()` aborts with the ambiguity message.

### P3 — MINOR (nice to have)
- **[P3.1]** [cg-code-quality/cg-testing] run_test_total.R:47 — the smoke script still defaults to the moving `master` branch.
  **Why**: That makes the verification output non-reproducible over time because live metadata and data can change whenever upstream updates `master`.
  **Fix**: Require an explicit pinned SPI ref for reproducible runs, or split live smoke mode from reproducible verification mode.

### ✅ Passed
- The previously fixed verify-scope items remain addressed: vignette knitr guard, README return-type wording, `.Rbuildignore` exclusion for `run_test_total.R`, `spi_aggregates()` doc alignment, and the `SPI` roxygen typo.
