---
date: 2026-07-13
depth: standard
type: standard
plan: .cg-docs/plans/2026-07-10-metadata-api.md
findings:
	P0.1: open
	P1.1: open
	P2.1: open
	P2.2: fixed
	P2.3: fixed
	P2.4: fixed
	P2.5: fixed
	P3.1: fixed
	P3.2: open
---

## Review Report

**Review mode**: standard
**Files reviewed**: 10
**Findings**: 9 (P0: 1, P1: 1, P2: 5, P3: 2)

### P0 — BLOCKING (immediate remediation required)

- **[P0.1]** [cg-data-quality] R/spi-wrappers.R:437 — metadata deduplication silently resolves conflicting upstream hierarchy text by taking the first row per key.
	**Why**: The new `pillar_name[1L]` / `dimension_name[1L]` / `indicator_name[1L]` collapse hides ambiguous upstream metadata instead of failing loudly. If upstream sends two different descriptions or IDs for the same hierarchy key, the package now returns an arbitrary variant based on row order.
	**Fix**: Validate that each hierarchy key maps to exactly one distinct descriptive payload before collapsing. If conflicting values exist, abort with `cli::cli_abort()` naming the offending key and fields.

### P1 — CRITICAL (must fix before merge)

- **[P1.1]** [cg-data-quality] .cg-docs/active-state/current.json:3 — active-state/work-report metadata was rewound to an older completed task while the metadata API plan remains active.
	**Why**: The working tree still changes the active metadata plan, but `current.json` now points back to the older country-info work and the matching metadata work report was removed. That corrupts protected workflow state and breaks the evidence trail for the current work.
	**Fix**: Restore or regenerate `.cg-docs/active-state/current.json` and the matching work-report reference so they reflect the actual metadata task status.

### P2 — IMPORTANT (should fix)

- **[P2.1]** [cg-testing] R/spi-data.R:52 — header normalization/collision behavior in `.spi_read_metadata()` is untested.
	**Why**: The loader now normalizes upstream headers and aborts on normalized-name collisions, but the test suite only covers missing-column and download-failure cases. A future upstream header change could break every metadata accessor without a targeted regression test.
	**Fix**: Add tests for successful normalization of spaced/punctuated headers and for collision aborts when two raw headers normalize to the same name.

- **[P2.2]** [cg-documentation] vignettes/spi-data-workflows.Rmd:197 — metadata examples used `\dontrun{}` inside an executable vignette chunk.
	**Why**: `\dontrun{}` is valid in Rd/roxygen, not in R Markdown code chunks, so the vignette section could fail to parse/render.
	**Fix**: Use a valid knitr guard such as `eval = FALSE`.

- **[P2.3]** [cg-documentation] README.md:102 — README claimed all functions return a single `data.table`.
	**Why**: `metadata()` returns a named list of `data.table`s, so the public API summary contradicted actual behavior.
	**Fix**: Clarify that `metadata()` returns a list and the remaining accessors return a single `data.table`.

- **[P2.4]** [cg-version-control] .Rbuildignore:8 — `run_test_total.R` was not excluded from the package build.
	**Why**: The expanded smoke script is a developer artifact similar to other excluded top-level scripts/files and should not be bundled.
	**Fix**: Add `^run_test_total\\.R$` to `.Rbuildignore`.

- **[P2.5]** [cg-documentation] R/spi-wrappers.R:110 — `spi_aggregates()` documentation overpromised return columns and described the output too narrowly.
	**Why**: The wrapper keeps only `iso3c`, `date`, `country`, `source_id`, and `value`, while docs mentioned additional fields and only "regional" rows.
	**Fix**: Align the roxygen/README/vignette wording with the actual wrapper contract.

### P3 — MINOR (nice to have)

- **[P3.1]** [cg-code-quality] R/spi-data.R:92 — roxygen title typo (`SxPI`).
	**Why**: The typo would leak into generated help and make the public docs look unreviewed.
	**Fix**: Change it back to `SPI`.

- **[P3.2]** [cg-reproducibility] run_test_total.R:47 — smoke validation defaults to the moving `master` branch.
	**Why**: The script output is not reproducible over time because live metadata and data can change whenever upstream updates `master`.
	**Fix**: Require an explicit pinned SPI release/ref for reproducible validation, or clearly separate live smoke mode from reproducible verification.

### ✅ Passed

- `cg-architecture`: no additional architecture/API findings beyond the consolidated issues above.
- `cg-performance`: no blocking performance issues beyond the current metadata construction approach.
- `cg-version-control`: no secret or token leakage detected in changed files.

