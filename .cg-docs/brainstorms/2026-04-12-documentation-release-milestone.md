---
date: 2026-04-12
title: "Documentation & Release — Milestone 3 planning"
status: decided
scope: "Standard"
chosen-approach: "Vignette-first, then infrastructure"
tags: [documentation, vignette, pkgdown, release, milestone-3]
---
<!-- Valid status values: decided, in-progress, abandoned -->

# Documentation & Release — Milestone 3 Planning

## Context
Milestone 3 ("Documentation & Release") in the roadmap covers four features:
README with examples, a vignette on SPI data workflows, R CMD check zero
warnings, and pkgdown site / GitHub release. Two features (README, R CMD check)
are already effectively done. The brainstorm focused on scoping the remaining
two: the vignette and distribution channel.

## Requirements
- **Audience**: Both internal World Bank staff and external researchers/academics.
- **README**: Already solid. Enhanced during this brainstorm with a brief SPI
  explainer, link to the SPI program page, and link to the SPI Handbook.
- **Vignette**: One comprehensive vignette ("SPI data workflows") covering data
  access, light analysis (country comparisons, time trends), and ggplot2
  visualizations. Adds `ggplot2` and `scales` to `Suggests`.
- **Distribution**: pkgdown site on GitHub Pages + tagged GitHub release. No
  CRAN submission.
- **R CMD check**: Already passing with Status: OK — maintain zero warnings.
- **Out of scope**: CRAN submission, second vignette, Milestone 2 inventory/raw
  data functions in this vignette, hex logo or custom pkgdown theme.

## Approaches Considered

### Approach 1: Vignette-first, then infrastructure (CHOSEN)
Write the vignette first (data access → analysis → visualization), then set up
pkgdown + GitHub Actions to render it, bump version, tag release.

**Pros**: The vignette is the highest-value deliverable and validates all package
functions end-to-end. Once it exists, pkgdown setup is mechanical. Catches any
API or function issues early.

**Cons**: If pkgdown reveals rendering issues (e.g., ggplot2 output in CI
without display), you fix them after writing.

**Effort**: Medium

### Approach 2: Infrastructure-first, then vignette
Set up pkgdown + CI + GitHub Pages first with the existing README, then add the
vignette knowing the rendering pipeline is already working, then tag release.

**Pros**: Validates the build pipeline early.

**Cons**: Delays the highest-value work (vignette). More deploy cycles for same
outcome.

**Effort**: Medium

### Approach 3: Parallel tracks
Build the vignette and pkgdown config simultaneously, merge everything at once.

**Pros**: Fastest wall-clock time if both streams are independent.

**Cons**: Harder to debug if something breaks. Riskier for single developer.

**Effort**: Medium

## Decision
Approach 1 — Vignette-first, then infrastructure. The vignette is the core
deliverable; infrastructure wraps around it and is mechanical once the content
exists.

## Next Steps
1. Add `ggplot2` and `scales` to `Suggests` in DESCRIPTION
2. Write the vignette (`vignettes/spi-data-workflows.Rmd`):
   - Section 1: Getting started — install, load, `spi_data()`, `spi_index()`,
     `spi_aggregates()`
   - Section 2: Filtering — by country, year, pillar, dimension, version
   - Section 3: Light analysis — compare countries across pillars, track
     changes over time
   - Section 4: Visualization — ggplot2 charts (bar, line, faceted) of SPI
     scores by region, pillar breakdown, time trends
3. Run R CMD check — confirm zero warnings with new vignette
4. Set up pkgdown: `_pkgdown.yml`, GitHub Actions workflow for GitHub Pages
5. Bump version in DESCRIPTION (0.1.0), update NEWS.md
6. Tag GitHub release (v0.1.0)
7. Verify pkgdown site renders correctly with vignette plots
