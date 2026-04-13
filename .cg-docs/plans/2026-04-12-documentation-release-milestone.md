---
date: 2026-04-12
title: "Documentation & Release — Milestone 3 implementation"
status: completed
completed-date: 2026-04-12
scope: "Standard"
brainstorm: ".cg-docs/brainstorms/2026-04-12-documentation-release-milestone.md"
language: "R"
estimated-effort: "medium"
tags: [documentation, vignette, pkgdown, release, milestone-3]
---

# Plan: Documentation & Release — Milestone 3 Implementation

## Objective
Finalize the spiR package for public use by writing a comprehensive vignette
(data access, analysis, visualization with ggplot2), setting up a pkgdown
site on GitHub Pages, bumping to v0.1.0, and tagging a GitHub release.

## Context
- Milestone 1 (Output Data Access MVP) is done — `spi_get()`, `spi_data()`,
  `spi_index()`, `spi_aggregates()`, `spi_versions()`, `spi_clear_cache()`
  all work with filtering and version support.
- README was enhanced during the brainstorm with an SPI explainer,
  program page link, and handbook link.
- R CMD check passes with Status: OK (zero warnings/errors).
- No vignette infrastructure exists yet: no `vignettes/` directory, no
  `VignetteBuilder` in DESCRIPTION, no knitr/rmarkdown in Suggests.
- CI exists: `.github/workflows/R-CMD-check.yaml` using `r-lib/actions`.
- `.gitignore` already ignores `vignettes/*.html` and `vignettes/*.pdf`.
- Brainstorm decided: vignette-first, then pkgdown + release.

## Requirements

| ID  | Requirement                                              | Source     |
|-----|----------------------------------------------------------|------------|
| R1  | Add ggplot2, scales, knitr, rmarkdown to Suggests        | brainstorm |
| R2  | Add VignetteBuilder: knitr to DESCRIPTION                | convention |
| R3  | Write vignette covering data access, filtering, analysis, visualization | brainstorm |
| R4  | Vignette examples use `\dontrun{}` or pre-computed data to avoid network calls during R CMD check | constraint |
| R5  | R CMD check passes with zero warnings after vignette     | charter    |
| R6  | Set up pkgdown with `_pkgdown.yml`                       | brainstorm |
| R7  | Add GitHub Actions workflow for pkgdown deployment        | brainstorm |
| R8  | Bump version to 0.1.0, update NEWS.md                    | brainstorm |
| R9  | Tag GitHub release v0.1.0                                | brainstorm |
| R10 | No CRAN submission, no hex logo, no custom theme          | brainstorm |

## Implementation Steps

### 1. Add vignette dependencies to DESCRIPTION
- **Requirements**: R1, R2
- **Files**: `DESCRIPTION`
- **Details**:
  - Add to `Suggests`: `knitr`, `rmarkdown`, `ggplot2`, `scales`
  - Add top-level field: `VignetteBuilder: knitr`
- **Acceptance criteria**: `devtools::check()` still passes after changes

### 2. Write the vignette
- **Requirements**: R3, R4
- **Files**: `vignettes/spi-data-workflows.Rmd` (create)
- **Details**:
  The vignette should use `eval = FALSE` globally (or per-chunk) to avoid
  network calls during `R CMD check`. Provide expected output as comments
  or static text where helpful. Structure:

  **Section 1 — Getting Started**
  - Install instructions (`remotes::install_github("WB-DECIS/spiR")`)
  - `library(spiR)` + brief package overview
  - Show `spi_data()`, `spi_index()`, `spi_aggregates()` basic calls
  - Show `spi_versions()` to list available data versions

  **Section 2 — Filtering Data**
  - Filter by country: `spi_data(country = c("NOR", "SWE"))`
  - Filter by year: `spi_data(year = 2020:2024)`
  - Filter by pillar: `spi_index(pillar = 3)`
  - Filter by dimension: `spi_index(dimension = "5.2")`
  - Filter by version: `spi_data(version = "SPI2023")`
  - Regional aggregates: `spi_aggregates(region = "...", pillar = 1)`

  **Section 3 — Comparing Countries**
  - Retrieve SPI index for a set of countries
  - Reshape pillar scores with `data.table::melt()`
  - Compare pillar profiles across countries (table + plot)
  - Track a single country over time

  **Section 4 — Visualization**
  - Bar chart: SPI overall scores for selected countries (ggplot2)
  - Grouped bar: pillar breakdown for a country vs. regional average
  - Line chart: SPI score trends over time for a group of countries
  - Faceted plot: pillar scores by country

  Use `ggplot2` with default theme (no wbplot — not a dependency). Keep
  plots simple and illustrative.

- **Test Scenarios**:
  - ✅ Vignette builds locally with `devtools::build_vignettes()`
  - 🛑 No network calls during `R CMD check` (all chunks `eval = FALSE`)
  - ❌ Missing package (ggplot2 not installed) — vignette still builds
    (since `eval = FALSE`)
- **Acceptance criteria**: Vignette renders to HTML locally; R CMD check
  passes with vignette present

### 3. Run R CMD check with vignette
- **Requirements**: R5
- **Files**: none (verification step)
- **Details**: Run `devtools::check()` and confirm Status: OK with zero
  warnings. Specifically check for:
  - No `VignetteBuilder` or missing dependency warnings
  - No undeclared imports from vignette code
  - Vignette builds without errors
- **Acceptance criteria**: `Status: OK` with 0 errors, 0 warnings, 0 notes

### 4. Set up pkgdown
- **Requirements**: R6, R10
- **Files**: `_pkgdown.yml` (create), `.github/workflows/pkgdown.yaml` (create)
- **Details**:
  - `_pkgdown.yml`:
    - Set `url` to `https://wb-decis.github.io/spiR/`
    - Set template to default (no custom theme per R10)
    - Organize reference into groups: "Data Access" (`spi_get`, `spi_data`,
      `spi_index`, `spi_aggregates`), "Versions & Cache" (`spi_versions`,
      `spi_clear_cache`, `spi_clear_inventory`, `spi_update_inventory`),
      "Filtering" (internal helpers — may exclude or place under "internal")
    - List the vignette under articles
  - `.github/workflows/pkgdown.yaml`:
    - Trigger on push to main/master
    - Use `r-lib/actions/setup-r@v2`, `r-lib/actions/setup-r-dependencies@v2`,
      `r-lib/actions/setup-pandoc@v2`
    - Build site with `pkgdown::build_site_github_pages()`
    - Deploy to `gh-pages` branch using standard `actions/deploy-pages`
    - Set `GITHUB_PAT` env for dependency installation
  - Add `pkgdown` to `Suggests` in DESCRIPTION (or `Config/Needs/website`)
  - Add `docs/` to `.gitignore` (pkgdown local builds)
  - Ensure GitHub Pages is enabled for the repo (manual step — document
    as a note in the plan)
- **Test Scenarios**:
  - ✅ `pkgdown::build_site()` runs locally and produces `docs/`
  - 🛑 Workflow YAML is valid (no syntax errors)
  - ❌ GitHub Pages not enabled — document as manual step
- **Acceptance criteria**: pkgdown builds locally without errors; workflow
  file is syntactically valid

### 5. Bump version and update NEWS.md
- **Requirements**: R8
- **Files**: `DESCRIPTION`, `NEWS.md`
- **Details**:
  - Change `Version: 0.0.0.9000` to `Version: 0.1.0` in DESCRIPTION
  - Add NEWS.md entry for v0.1.0:
    - Milestone 1 features (already documented under 0.0.0.9000 — move them)
    - New: vignette "SPI data workflows"
    - New: pkgdown site at `https://wb-decis.github.io/spiR/`
    - README: added SPI framework overview and links
- **Acceptance criteria**: Version reads `0.1.0`; NEWS.md is well-formatted

### 6. Final R CMD check
- **Requirements**: R5
- **Files**: none (verification step)
- **Details**: Run `devtools::check()` one final time after all changes.
  Confirm zero errors, zero warnings, zero notes.
- **Acceptance criteria**: `Status: OK`

### 7. Tag GitHub release
- **Requirements**: R9
- **Files**: none (GitHub action)
- **Details**:
  - Commit all changes to `main`
  - Create git tag `v0.1.0`
  - Push tag to origin
  - Create GitHub release from the tag with release notes from NEWS.md
  - Verify pkgdown site deploys successfully after push
- **Test Scenarios**:
  - ✅ Tag exists on remote: `git tag -l v0.1.0`
  - ✅ pkgdown site is live at `https://wb-decis.github.io/spiR/`
  - ✅ Vignette is rendered on the pkgdown site
- **Acceptance criteria**: GitHub release page shows v0.1.0; pkgdown site
  is live with rendered vignette

## Testing Strategy
- **Vignette code**: All chunks use `eval = FALSE` to avoid network
  dependencies during R CMD check. The vignette is tested manually by
  running chunks interactively.
- **R CMD check**: Run after Steps 2, 3, and 6 to catch issues early.
- **pkgdown**: Build locally before pushing the workflow to catch rendering
  issues.
- **Existing tests**: Run existing testthat suite to confirm no regressions.

## Documentation Checklist
- [ ] Vignette: `vignettes/spi-data-workflows.Rmd`
- [ ] NEWS.md updated for v0.1.0
- [ ] README already updated (done in brainstorm)
- [ ] pkgdown reference organized by function group
- [ ] DESCRIPTION version bumped to 0.1.0

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| GitHub Pages not enabled for WB-DECIS/spiR repo | pkgdown site won't deploy | Medium | Document as manual step; can be done by repo admin |
| ggplot2 plots render differently across R versions | Visual inconsistencies in vignette | Low | Use `eval = FALSE` in vignette; plots are illustrative |
| GITHUB_TOKEN lacks Pages deployment permissions | CI workflow fails | Medium | May need `pages: write` permission in workflow YAML; use `actions/deploy-pages` pattern |

## Out of Scope
- CRAN submission
- Second vignette
- Hex logo or custom pkgdown theme
- Milestone 2 inventory/raw data functions in this vignette
- wbplot integration (not a package dependency)
