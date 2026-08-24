---
date: 2026-08-04
title: "SPI Metadata API Review Follow-up"
status: active
scope: "Standard"
phases: 3
brainstorm: null
parent-plan: ".cg-docs/plans/2026-07-10-metadata-api.md"
review-context: ".cg-docs/reviews/2026-07-10-metadata-api-review.md"
language: "R"
estimated-effort: "medium"
deviation-policy: "ask"
execution-report: ".cg-docs/work-reports/2026-08-04-metadata-api-review-follow-up.md"
completed-phases: [1, 2, 3]
failing-steps: [3]
tags: [api, metadata, refactor, review-follow-up, testing]
---

# Plan: SPI Metadata API Review Follow-up

## Objective

Record and implement the review modifications to the original SPI Metadata API
plan. Add an indicator metadata wrapper, give the metadata catalog its own
source file, and extract validation checks from the metadata reader and public
metadata function while preserving the existing API behavior.

This plan is a follow-up to [the original metadata API plan](2026-07-10-metadata-api.md),
not a replacement for it. The original plan remains the historical record of
the initial implementation; this plan records the review-driven differences.

## Context

The current metadata implementation is split between `R/spi-data.R` and
`R/spi-wrappers.R`. `.spi_read_metadata()` combines downloading, header
normalization, schema validation, and key normalization. `metadata()` combines
argument validation, metadata resolution, hierarchy validation, filtering, and
summary construction.

The review follow-up must preserve the fail-loudly project rule. In particular,
hierarchy summaries must use stable keys and must reject conflicting names,
descriptions, or IDs for the same hierarchy key instead of silently selecting
the first row.

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| R1 | Add and export `metadata_indicators()`, returning the indicator metadata table from `metadata()` with the same filter semantics. | User review request |
| R2 | Consolidate metadata-specific constants, internal helpers, loader, `metadata()`, and all metadata wrappers into one `R/spi-metadata.R` script. | User review request |
| R3 | Extract `.spi_read_metadata()` checks into a focused helper and call that helper from the reader. | User review request |
| R4 | Extract `metadata()` input and hierarchy checks into focused helpers and call them from `metadata()`. | User review request |
| R5 | Preserve existing filtering, error, warning, deduplication, and return-shape behavior. | Parent plan and review |
| R6 | Reject conflicting descriptive payloads or IDs that share a stable hierarchy key. | Project rule and review finding P0.1 |
| R7 | Add focused regression tests, regenerate documentation and exports, and pass package checks. | Parent plan and project quality gates |
| R8 | Create one granular commit after each requested task is complete. | User review request |

## Implementation Steps

## Phase 1: Public API Delta

### 1. Add `metadata_indicators()`

- **Requirements**: R1, R5, R7, R8
- **Files**: `R/spi-wrappers.R`, `tests/testthat/test-spi-metadata.R`, generated metadata documentation, `NAMESPACE`
- **Details**:
  - Add `metadata_indicators()` as a thin projection of `metadata()` returning
    the `$indicators` table.
  - Support `pillar`, `dimension`, `indicator`, and `version` so the wrapper
    exposes the existing metadata filter semantics without duplicating them.
  - Document that this returns indicator definitions and metadata, not
    country-level indicator scores returned by `spi_indicator()`.
  - Add tests for the default result, pillar and dimension filters, direct
    indicator lookup, and version forwarding.
  - Regenerate the namespace and `man/metadata_indicators.Rd`.
- **Test Scenarios**: default call, filtered call, indicator lookup, invalid filter, no network call.
- **Tests**: `testthat::test_file("tests/testthat/test-spi-metadata.R")`
- **Acceptance criteria**: `metadata_indicators()` returns the same indicator
  table that the equivalent `metadata()` call would return and is exported and
  documented.
- **Commit**: `feat(metadata): add indicator metadata wrapper`

## Phase 2: Metadata Source Ownership

### 2. Consolidate metadata implementation

- **Requirements**: R2, R5, R7, R8
- **Files**: new `R/spi-metadata.R`, `R/spi-data.R`, `R/spi-wrappers.R`, metadata tests
- **Details**:
  - Move `SPI_METADATA_PATH`, required metadata column definitions,
    `.spi_read_metadata()`, `.metadata_normalize_arg()`,
    `.metadata_resolve_filter()`, `metadata()`, `metadata_pillars()`,
    `metadata_dimensions()`, and `metadata_indicators()` into
    `R/spi-metadata.R`.
  - Remove the moved metadata code from the previous scripts without changing
    `country_info()` or the output-data wrappers.
  - Keep all metadata-specific code in the new script, including helpers added
    in Phase 3.
  - Confirm that package source loading, internal symbol resolution, and
    generated documentation remain valid after the relocation.
- **Test Scenarios**: package load, all existing metadata tests, non-metadata wrapper smoke tests.
- **Tests**: `testthat::test_file("tests/testthat/test-spi-metadata.R")`; `devtools::test()`
- **Acceptance criteria**: metadata functions have one source-file owner, no
  metadata behavior changes, and the focused suite passes without network calls.
- **Commit**: `refactor(metadata): consolidate metadata implementation`

## Phase 3: Validation Decomposition

### 3. Extract reader and API validation helpers

- **Requirements**: R3, R4, R5, R6, R7, R8
- **Files**: `R/spi-metadata.R`, `tests/testthat/test-spi-metadata.R`
- **Details**:
  - Add a focused reader/schema helper for normalized headers,
    normalized-name collisions, and required-column validation; call it from
    `.spi_read_metadata()` while keeping the reader focused on download,
    normalization, key canonicalization, and return flow.
  - Add focused metadata validation helpers for argument type/format checks and
    resolved hierarchy consistency; call them from `metadata()` while keeping
    table construction and filtering readable.
  - Preserve validation order: malformed filters fail before downloading, while
    metadata-dependent hierarchy checks run after loading and resolving filters.
  - Validate stable hierarchy keys before collapsing descriptive fields. Abort
    with `cli::cli_abort()` when a pillar, dimension, or indicator key maps to
    conflicting names, descriptions, or IDs.
  - Add regression tests for successful header normalization, normalized-header
    collisions, invalid arguments, pillar/dimension mismatches,
    dimension/indicator mismatches, repeated stable keys, and conflicting
    hierarchy payloads.
- **Test Scenarios**: valid metadata, missing required column, header collision,
  invalid filter, hierarchy mismatch, duplicate stable key with identical text,
  duplicate stable key with conflicting text, no-match warning.
- **Tests**: `testthat::test_file("tests/testthat/test-spi-metadata.R")`
- **Acceptance criteria**: `.spi_read_metadata()` and `metadata()` delegate their
  checks to external helpers; all existing and new validation tests pass; the
  fail-loudly behavior is retained.
- **Commit**: `refactor(metadata): extract validation helpers`

## Testing Strategy

- Mock `spi_download()` in every metadata unit test so focused tests never
  require network access.
- Run the focused metadata test file after each phase and the full test suite
  after Phase 2 and Phase 3.
- Regenerate documentation with `roxygen2::roxygenise()` before the final
  package check.
- Run `R CMD check --no-manual .` and `git diff --check` after all three
  granular commits.

## Documentation Checklist

- [ ] Add roxygen documentation for `metadata_indicators()` and distinguish it from `spi_indicator()`.
- [ ] Regenerate `NAMESPACE` and all metadata `.Rd` files.
- [ ] Confirm internal validation helpers are not exported.
- [ ] Confirm the parent-plan link and review context remain in this plan's frontmatter.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| `metadata_indicators()` is confused with `spi_indicator()`. | Explain the distinct return contracts in roxygen documentation and test the metadata table shape. |
| Moving functions changes package source ordering or namespace loading. | Run focused tests immediately after relocation and verify package loading. |
| Extracted validation changes error timing or messages. | Preserve validation order and existing test expectations. |
| Conflicting upstream metadata is silently accepted. | Validate descriptive payload uniqueness by stable hierarchy keys and add regression tests. |
| Generated exports or help files become stale. | Run `roxygen2::roxygenise()` and verify `NAMESPACE` and generated metadata pages. |
| Unrelated worktree changes are overwritten during the refactor. | Keep edits scoped to metadata code, tests, generated metadata docs, and `NAMESPACE`; inspect diffs before each commit. |

## Out of Scope

- Changes to `spi_get()`, `spi_indicator()`, or unrelated data wrappers.
- Persistent metadata caching.
- README, vignette, or active-state workflow repairs unless separately requested.
- New package dependencies.
- Roadmap edits inside this plan.

## Completion Contract

### Outcome

The review follow-up is implemented as a documented modification of the parent
metadata API plan. `metadata_indicators()` is available and documented, all
metadata catalog code has one file owner, and reader/API validation is split
into focused helpers without changing public behavior.

### Verification Surface

| ID | Phase | Evidence Required | Command/Artifact | Required |
|----|-------|-------------------|------------------|---------|
| V1 | 1 | `metadata_indicators()` returns an indicator metadata `data.table` and honors filters. | Focused metadata tests | yes |
| V2 | 2 | Metadata-specific functions exist in `R/spi-metadata.R` and are removed from the previous scripts. | Source inspection plus package tests | yes |
| V3 | 3 | Reader validation is delegated to an external helper. | Focused loader tests and source inspection | yes |
| V4 | 3 | `metadata()` validation is delegated to external helpers while preserving hierarchy errors. | Focused metadata tests | yes |
| V5 | 3 | Header collisions and conflicting hierarchy payloads fail loudly. | Regression tests | yes |
| V6 | final | Generated exports and documentation are current and package checks pass. | `roxygen2::roxygenise()` and `R CMD check --no-manual .` | yes |

### Constraints

| ID | Phase | Constraint | Check |
|----|-------|------------|-------|
| C1 | final | No new dependencies. | Review `DESCRIPTION` diff |
| C2 | final | Existing metadata return shapes and error behavior do not regress. | Existing and new metadata tests |
| C3 | 2 | Metadata catalog implementation has one R script owner. | Source inspection |
| C4 | 3 | Stable hierarchy keys control deduplication and ambiguity checks. | Duplicate/conflict regression tests |
| C5 | all | Each requested task has its own commit boundary. | Git log and diff review |

### Boundaries

- Allowed: new `R/spi-metadata.R`, metadata portions of `R/spi-data.R` and
  `R/spi-wrappers.R`, metadata tests, generated metadata documentation, and
  `NAMESPACE`.
- Out of scope: unrelated wrapper behavior, broader package refactors, active
  workflow state changes, and roadmap edits.

### Iteration Policy

1. Repair failures within the current phase and rerun its focused test command.
2. Preserve the parent API unless a failing test demonstrates that the
   requested change requires an explicit adjustment.
3. Record any unavoidable deviation before continuing under
   `deviation-policy: ask`.
4. Run the full package check only after all three task commits are complete.

### Blocked-Stop Conditions

- Required focused tests or package checks cannot run.
- Moving the functions causes an unresolved package-load or namespace failure.
- Existing public metadata behavior must change beyond the stated requirements.
- A required validation cannot be preserved without an API decision.
- A protected workflow boundary must be modified to proceed.
