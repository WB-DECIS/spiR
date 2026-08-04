---
date: 2026-08-04
title: "Improve spiR visualization chart dependencies, axes, labels, and metadata names"
completed-phases: [1, 2, 3]
failing-steps: []
scope: "Standard"
brainstorm: ".cg-docs/brainstorms/2026-07-29-viz-ggplot-wb-guidelines-port.md"
language: "R"
estimated-effort: "medium"
deviation-policy: "ask"
execution-report: ".cg-docs/work-reports/2026-08-04-spi-visualization-chart-improvements.md"
tags: [visualization, ggplot2, ggrepel, time-series, metadata, dependencies, testthat]
completed-date: 2026-08-04
status: completed
---

# Plan: Improve spiR visualization chart dependencies, axes, labels, and metadata names

## Objective

Improve the existing `spi_plot_*()` chart module so its plotting dependencies are
accurately declared, time-series axes use the observed data range, final-year
ticks remain readable, latest-value labels identify each series without
cluttering the chart, and titles and legends use human-readable SPI metadata.

This is a follow-up to
[2026-07-30-spi-visualization-module-complete.md](2026-07-30-spi-visualization-module-complete.md).
The earlier v1 decision to display raw SPI column names is superseded for this
follow-up by the user's requirement for metadata-derived names.

## Context

The current plotting functions call `ggplot2` through qualified namespaces, but
`ggplot2` remains in `Suggests`. The time-series functions also use a fixed
implicit data domain, causing charts to begin at 2005 even when the first
observed value is later, and the final year can be clipped to a label such as
`202` rather than `2025`. Series currently use legends without latest-point
labels, and several titles or legend values expose raw identifiers such as
`SPI.INDEX.PIL1`.

The implementation must preserve the existing package decisions that regional
charts use official `spi_aggregates()` rows and that World Bank styling is
implemented internally rather than through `wbplot`. Metadata joins must use
stable hierarchy identifiers, not descriptive text, because upstream metadata
can contain textual variants.

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| R1 | Declare `ggplot2` as a required package dependency and add `ggrepel` as a required dependency for the supported latest-value label behavior; keep map-only `sf` and `ggiraph` optional. Synchronize `DESCRIPTION`, generated namespace metadata where applicable, and `renv.lock`. | User request; package dependency contract |
| R2 | Add shared time-series scale logic that starts the x-axis at the previous five-year interval containing the first observed non-missing year. For example, data beginning in 2016 starts at 2015; data beginning in 2015 starts at 2015. | User request |
| R3 | Ensure the final observed year has enough right-side scale expansion or an equivalent explicit domain so its tick label is fully visible. | User request |
| R4 | Add latest-value labels only to the latest non-missing observation in each plotted series. Do not label every point or use an earlier point when a later non-missing value exists. | User request |
| R5 | Use stable series codes for latest-value labels: ISO3 codes for countries, canonical aggregate codes for regions, and SPI codes for pillars, dimensions, and indicators. Preserve those identifiers separately from human-readable display names. | User request; metadata and aggregate data contracts |
| R6 | Resolve human-readable display names from SPI metadata for titles and legends. At minimum, render `SPI.INDEX` as an SPI Index label and `SPI.INDEX.PIL1` as `Pillar 1: Data Use`; support the corresponding pillar, dimension, and indicator hierarchy without joining on descriptive text. | User request; metadata hierarchy solution |
| R7 | Apply the shared axis, latest-label, and display-name behavior consistently across `spi_plot_pillars()`, `spi_plot_trend()`, `spi_plot_country_vs_region()`, `spi_plot_regions()`, and `spi_plot_region_pillars()`. Apply metadata display names to the radar chart where titles or legends identify SPI series. | User request; existing chart catalogue |
| R8 | Keep official regional aggregate values and existing fail-loudly behavior intact while adding presentation metadata and labels. | Existing visualization hardening solution |
| R9 | Add focused regression tests for dependency declarations, axis-domain calculation, final-year expansion, latest-value selection, series-code labels, metadata name resolution, and chart-level integration. | Testing requirement |
| R10 | Update user-facing plotting documentation and generated man pages so dependency requirements, latest-value labels, axis behavior, and metadata-based names are accurately described. | Documentation requirement |

## Implementation Steps

## Phase 1: Dependencies and shared presentation helpers

### 1. Align plotting dependencies and environment metadata

- **Requirements**: R1
- **Files**: `DESCRIPTION`, `NAMESPACE`, `renv.lock`
- **Details**:
  - Move `ggplot2` from `Suggests` to `Imports`.
  - Add `ggrepel` to `Imports` with a compatible minimum version.
  - Keep `sf` and `ggiraph` in `Suggests` because they are used only by the map path.
  - Regenerate namespace and synchronize the renv lockfile using the repository's existing package workflow.
  - Preserve the package's existing dependency policy and do not add `dplyr`, `tidyr`, or `wbplot`.
- **Test Scenarios**: declarations are present in the correct sections; map-only packages remain optional; package dependency metadata is internally consistent.
- **Tests**: DESCRIPTION/NAMESPACE inspection; lockfile validation; package load check.
- **Acceptance criteria**: A clean package environment treats `ggplot2` and `ggrepel` as required for the supported chart API, while map-only dependencies remain optional.

### 2. Create shared axis, latest-observation, series-code, and metadata-label helpers

- **Requirements**: R2, R3, R4, R5, R6, R8
- **Files**: `R/spi-plot-helpers.R`, `R/spi-plot-style.R`
- **Details**:
  - Add a helper that derives the first observed non-missing year and floors it to the applicable five-year interval.
  - Add a shared x-scale builder with explicit breaks/domain and right-side expansion sufficient to display the final year completely.
  - Add a helper that selects exactly one latest non-missing row per series, preserving deterministic ordering and returning no label row for an all-missing series.
  - Keep series identifiers and display labels as separate columns. Resolve country labels from ISO3 values, resolve region labels from canonical aggregate codes, and retain SPI source codes for pillar/dimension/indicator series.
  - Add a metadata resolver based on stable fields such as `pillar`, `dimension`, `indicator`, and their corresponding IDs. Define consistent display rules for overall index, pillars, dimensions, and indicators, with explicit errors when required metadata cannot be resolved rather than silently reverting to raw text.
  - Keep helpers compatible with `data.table` and existing `cli` error handling.
- **Test Scenarios**: first year 2016 maps to 2015; first year on a five-year boundary is unchanged; missing leading values are ignored; final-year tick remains inside the plotted domain; latest labels ignore earlier points and missing terminal values; duplicate metadata descriptions do not change stable-key resolution.
- **Tests**: `tests/testthat/test-spi-plot-helpers.R`.
- **Acceptance criteria**: All chart functions can consume one shared contract for temporal domains, latest rows, stable series codes, and human-readable SPI display names.

## Phase 2: Apply shared behavior to charts

### 3. Apply corrected time-series axes and latest-value labels

- **Requirements**: R2, R3, R4, R5, R7, R8
- **Files**: `R/spi-plot-pillars.R`, `R/spi-plot-trend.R`, `R/spi-plot-country-vs-region.R`, `R/spi-plot-regions.R`, `R/spi-plot-region-pillars.R`
- **Details**:
  - Replace the current implicit/fixed x-axis behavior with the shared x-scale helper in every time-series chart.
  - Add `ggrepel::geom_text_repel()` using only the latest non-missing point per series, with stable code labels and clipping-safe plot margins or expansion.
  - Ensure country series use ISO3 codes even when the chart's legend uses country names, and region series use canonical aggregate codes even when the legend uses region names.
  - Ensure pillar and other SPI series labels retain their SPI source codes while their legends use resolved display names.
  - Preserve existing official aggregate routing, y-scale detection, colors, and return classes.
- **Test Scenarios**: multi-country charts with different start years; a series whose final row is missing; a series with only one valid point; regional aggregate series; pillar charts with partial data; no regressions in `ggplot` return classes.
- **Tests**: existing visualization chart tests plus focused layer-data assertions in `tests/testthat/test-spi-plot-functions.R` or the relevant chart test files.
- **Acceptance criteria**: Every affected time-series chart starts near its actual data, displays the final year intact, and has at most one latest-value label per series.

### 4. Apply metadata display names to titles, legends, and radar output

- **Requirements**: R5, R6, R7, R8
- **Files**: `R/spi-plot-pillars.R`, `R/spi-plot-trend.R`, `R/spi-plot-country-vs-region.R`, `R/spi-plot-regions.R`, `R/spi-plot-region-pillars.R`, `R/spi-plot-radar.R`, `R/spi-plot-helpers.R`
- **Details**:
  - Replace raw identifiers in titles and legend labels with resolved display names.
  - Use concise, consistent forms such as `SPI Index over time` and `Pillar 1: Data Use` while retaining the source code in the latest-value label or another stable internal field.
  - Keep country and region names suitable for legends, but use ISO3/canonical aggregate codes for endpoint labels.
  - Use the same metadata mapping for time-series and radar series so the chart catalogue does not present conflicting names.
  - Decide and document the display format for dimensions and indicators using the metadata name plus its hierarchy/code where needed to avoid ambiguous labels.
- **Test Scenarios**: overall index, all five pillars, a dimension, an indicator, duplicate metadata text variants, metadata lookup failure, country-versus-region title and legend composition, radar subtitle/legend naming.
- **Tests**: chart-level tests and metadata helper tests.
- **Acceptance criteria**: No affected title or legend exposes a raw SPI identifier when a valid metadata name exists, and stable codes remain available for endpoint labels.

## Phase 3: Regression coverage, documentation, and validation

### 5. Expand focused visualization regression tests

- **Requirements**: R4, R5, R6, R7, R9
- **Files**: `tests/testthat/test-spi-plot-helpers.R`, `tests/testthat/test-spi-plot-functions.R`, and affected visualization test files if split by chart.
- **Details**:
  - Add deterministic data.table fixtures covering staggered start years, missing terminal observations, multiple series, official aggregate codes, and metadata hierarchy rows.
  - Inspect built plot layers or helper outputs rather than relying only on visual snapshots.
  - Assert the latest-label layer contains one row per eligible series and the expected codes.
  - Assert x-axis limits/breaks include the final year and use the expected five-year start.
  - Assert titles and legends contain metadata-derived names and do not regress to raw identifiers.
  - Keep network calls mocked and clear any stateful package caches at test boundaries where needed.
- **Test Scenarios**: happy paths, all-missing series, missing metadata, duplicate metadata variants, non-boundary start years, five-year-boundary start years, and mixed index/share scales.
- **Tests**: focused visualization test files; `devtools::test(filter = "spi-plot")`.
- **Acceptance criteria**: Tests fail for the old 2005 axis behavior, all-point labeling behavior, clipped final tick, and raw metadata labels, then pass with the implementation.

### 6. Update documentation and generated package artifacts

- **Requirements**: R1, R6, R7, R10
- **Files**: `README.md`, affected Roxygen blocks under `R/spi-plot-*.R`, generated `man/*.Rd`, and `renv.lock` if dependency synchronization changes it.
- **Details**:
  - Document that `ggplot2` and `ggrepel` are required for the chart API and that `sf`/`ggiraph` remain map-specific optional dependencies.
  - Describe the observed-range five-year axis behavior and latest-value endpoint labels.
  - Document metadata-derived title and legend naming, including overall index and pillar examples.
  - Regenerate man pages without unrelated documentation churn.
- **Test Scenarios**: documentation examples reference current behavior; generated files match Roxygen source; package documentation builds without new warnings.
- **Tests**: `roxygen2::roxygenise()` as applicable; documentation/package load check.
- **Acceptance criteria**: User-facing documentation accurately describes the new chart contracts and generated artifacts are synchronized.

### 7. Run final package and visualization validation

- **Requirements**: R1, R7, R8, R9, R10
- **Files**: repository-wide validation surface; no additional source scope.
- **Details**:
  - Run focused visualization tests first, then the complete test suite.
  - Run package load/check validation available in the repository and distinguish pre-existing DESCRIPTION/check failures from regressions introduced by this plan.
  - Review the final diff for dependency, generated-documentation, and unrelated-file churn.
- **Test Scenarios**: focused tests, full test suite, package check, clean dependency declarations.
- **Tests**: `devtools::test(filter = "spi-plot")`, `devtools::test()`, and the repository's existing check command where available.
- **Acceptance criteria**: Focused visualization behavior is green, the full suite has no new failures, and any unrelated baseline failure is explicitly recorded.

## Testing Strategy

Use deterministic `data.table` fixtures and `local_mocked_bindings()` for
`spi_index()`, `spi_data()`, `spi_aggregates()`, `country_info()`, and metadata
accessors. Test helper outputs and ggplot layer data directly so axis and label
behavior is verified without depending on rasterized image comparisons. Keep
network-dependent map tests excluded from this change except for ensuring the
new required plotting dependencies do not alter map dependency guards.

## Documentation Checklist

- [ ] `ggplot2` and `ggrepel` dependency roles are documented.
- [ ] Five-year observed-range x-axis behavior is documented.
- [ ] Latest-value endpoint labels and their code conventions are documented.
- [ ] Metadata-derived title and legend naming is documented with examples.
- [ ] Roxygen blocks and generated man pages are synchronized.
- [ ] No unrelated README or generated-documentation changes are introduced.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Upstream metadata contains duplicate or variant descriptions | Join and resolve by stable hierarchy keys; test duplicate text variants. |
| Aggregate rows do not expose a consistent region code | Preserve the canonical aggregate identifier during normalization and fail loudly when it is unavailable rather than labeling with an unstable display name. |
| `ggrepel` changes plot layer structure or behaves differently across versions | Pin a compatible minimum version, test layer data rather than pixel output, and keep label inputs deterministic. |
| Axis expansion fixes clipping but creates excessive whitespace | Centralize the x-scale policy and test both the first five-year interval and final tick inclusion. |
| Missing terminal observations cause incorrect endpoint labels | Select the latest non-missing observation per series and test all-missing and trailing-missing cases. |
| Dependency changes break minimal package installation or map-only workflows | Keep `sf` and `ggiraph` optional, synchronize DESCRIPTION/NAMESPACE/renv, and run package load/check validation. |
| Metadata lookup adds network or cache sensitivity to otherwise mocked chart tests | Mock metadata accessors in focused tests and retain explicit error paths for unavailable metadata. |

## Out of Scope

- New chart types, including lollipop charts.
- Shiny or website integration.
- Redesign of map geometry, map interactivity, or map styling.
- Changes to `spi_get()`, `spi_data()`, `spi_index()`, `spi_aggregates()`, or metadata download semantics beyond the plotting resolver needed here.
- Manual edits to `roadmap.json` or `.cg-docs/active-state/current.json`.
- Unrelated package check failures already present before this work.

## Completion Contract

### Outcome

The `spi_plot_*()` chart API declares and uses its required plotting packages,
all affected time-series charts use an observed five-year x-axis domain with a
fully visible final tick, and each series receives at most one latest-value
label using a stable code. Titles and legends use metadata-derived human names
while preserving stable source identifiers for endpoint labels and joins.

### Verification Surface

| ID | Phase | Evidence Required | Command/Artifact | Required |
|----|-------|-------------------|------------------|----------|
| V1 | 1 | Required and optional plotting dependencies are correctly declared and synchronized | `DESCRIPTION`, `NAMESPACE`, `renv.lock`, package load check | yes |
| V2 | 1 | Shared axis, latest-row, stable-code, and metadata-label helpers pass boundary and error tests | `tests/testthat/test-spi-plot-helpers.R` | yes |
| V3 | 2 | All five time-series functions use the shared axis and latest-label behavior | affected chart tests and ggplot layer assertions | yes |
| V4 | 2 | Titles, legends, and radar labels use metadata-derived names | chart tests for index, pillar, dimension, and indicator identifiers | yes |
| V5 | 3 | Documentation and generated man pages describe the updated behavior | `README.md`, Roxygen sources, `man/*.Rd` | yes |
| V6 | 3 | Focused and full tests pass without new failures | `devtools::test(filter = "spi-plot")`; `devtools::test()` | yes |
| V7 | 3 | Final package validation distinguishes new failures from known baseline failures | repository check command and final diff review | yes |

### Constraints

| ID | Constraint | Check |
|----|------------|-------|
| C1 | Keep `data.table` as the data-processing backend | Source review and focused tests |
| C2 | Preserve official SPI aggregate routing for regional charts | Aggregate mock assertions |
| C3 | Keep `sf` and `ggiraph` optional map dependencies | DESCRIPTION review |
| C4 | Resolve metadata through stable identifiers, never descriptive text alone | Metadata helper tests |
| C5 | Preserve fail-loudly behavior for missing data, metadata, or identifiers | Error-path tests |
| C6 | Do not modify protected workflow or roadmap artifacts in this plan | Git diff review |

### Boundaries

- **Allowed**: plotting helpers, affected plot functions, plotting dependencies,
  lockfile synchronization, focused tests, README/Roxygen/man updates.
- **Out of scope**: new visualizations, core data-access redesign, map redesign,
  Shiny integration, manual roadmap/workflow state changes, unrelated fixes.

### Iteration Policy

1. Implement and validate shared helpers before modifying all chart renderers.
2. Run the narrowest affected visualization test after each substantive slice.
3. Repair local failures in the same slice and rerun the focused test before expanding scope.
4. Use explicit errors for unavailable metadata or unstable series identifiers.
5. Ask before deviating from the listed scope or changing the dependency policy.

### Blocked-Stop Conditions

- Required dependencies cannot be installed or synchronized.
- Stable metadata or aggregate identifiers are unavailable and no deterministic
  contract can be established.
- Focused tests remain failing after two repair attempts for the same slice.
- The implementation requires changes to core data-access semantics.
- Required validation commands cannot run.
