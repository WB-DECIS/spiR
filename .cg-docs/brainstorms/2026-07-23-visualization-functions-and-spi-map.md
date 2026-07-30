---
date: 2026-07-23
title: "Visualization architecture — reusable functions with SPI world hover map"
status: superseded
superseded-by: 2026-07-29-viz-ggplot-wb-guidelines-port.md
chosen-approach: "Layered visualization API with reusable data-prep + render functions"
tags: [visualization, api-design, shiny, plotly, map, spi-index]
---

> **Superseded by [2026-07-29-viz-ggplot-wb-guidelines-port.md](2026-07-29-viz-ggplot-wb-guidelines-port.md).**
> The layering principle still holds, but the direction shifted from a plotly
> wrapper fed by CSV to ggplot2 + wbplot functions fed by `spi_index()`/
> `spi_data()`, generalized to pillars/dimensions/indicators.

# Visualization Function Architecture

## Context

The package already provides stable data access functions (`spi_get()`,
`spi_index()`, `country_info()`, metadata helpers) with validation and
consistent filtering by `version`, `country`, `year`, `pillar`, and
`dimension`.

The new objective is to build web visualizations that are easy to reuse
across pages. The first required visualization is a world map where hovering
over a country shows its SPI index.

A key product decision is whether to implement visualization logic directly in
Shiny or to build reusable plotting functions first and let Shiny consume them.

## Requirements

1. The first page must show an interactive world map.
2. Hover must show at least country name and SPI index value.
3. Visualization logic should be reusable for future charts/pages.
4. The design should support both Shiny and non-Shiny contexts (reports,
   vignettes, scripts, pkgdown examples).
5. Missing SPI values must be handled explicitly (no silent fallbacks).
6. The API should remain consistent with existing package argument patterns.

## Approaches Considered

### Approach 1: Build map directly inside Shiny server

Implement all filtering, formatting, and rendering in reactive blocks inside
`server()`.

- Pros: Fastest path to a single working page.
- Cons: Hard to test, hard to reuse, duplicates logic across pages,
  tightly couples data and UI.
- Risk: Future visualizations become fragmented and inconsistent.

### Approach 2: One large map function only

Create a single function (for example `spi_index_map()`) that fetches data,
formats hover labels, and renders the map in one place.

- Pros: Simple entry point for users.
- Cons: Grows quickly in complexity; difficult to reuse internals for other
  charts; harder to test edge cases in isolation.
- Risk: Becomes a monolith as requirements expand (themes, legends, faceting,
  multiple value columns).

### Approach 3: Layered visualization API (recommended)

Split responsibilities into small reusable functions and provide a single
high-level wrapper for convenience.

- Pros: Reusable, testable, maintainable; compatible with Shiny and
  non-Shiny use; clear contracts between steps.
- Cons: Slightly more upfront design.
- Risk: Minimal, if naming conventions are kept simple.

## Decision

Use **Approach 3**: a layered visualization API.

- Keep Shiny as an integration layer.
- Implement reusable package functions for data preparation, hover text, and
  map rendering.
- Expose one user-facing wrapper for the page use case.

## Proposed Function Set

1. `spi_vis_map_data()`
- Purpose: Retrieve and normalize map-ready country-level data.
- Inputs: `year`, `version`, `country`, `value_col` (default `"SPI.INDEX"`),
  optional metadata enrichment flag.
- Output: One row per `iso3c` for the selected year, with `country`, `value`,
  and optional metadata columns.

2. `spi_vis_hover_text()`
- Purpose: Create standardized hover labels.
- Inputs: map-ready table, label options, number formatting options.
- Output: same table plus `hover_text` column.

3. `spi_vis_world_map()`
- Purpose: Render a world choropleth from a standardized table.
- Inputs: table, column names, palette settings, NA color, title.
- Output: interactive plot object (plotly widget).

4. `spi_index_map()` (high-level wrapper)
- Purpose: End-user convenience function for page-level usage.
- Internal flow: `spi_vis_map_data()` -> `spi_vis_hover_text()` ->
  `spi_vis_world_map()`.

## Data Contract for the Map

Minimum required columns in the render step:

- `iso3c` (ISO-3 country code)
- `country` (display label)
- `date` (year)
- `value` (SPI measure, default from `SPI.INDEX`)
- `hover_text` (prepared label)

## Error and Missing-Data Policy

1. If requested `value_col` is absent, stop with a clear error.
2. If the selected year has no rows, stop with a clear error.
3. If `value` is `NA`, keep country visible with neutral color and hover text
   such as "No data".
4. If multiple rows remain per country-year, resolve deterministically and
   document the rule.

## Shiny Integration Pattern

Shiny should call `spi_index_map(...)` inside `renderPlotly()` and keep UI
concerns in Shiny only (inputs/layout/theme). Data and visualization logic
remain in package functions.

This keeps behavior consistent whether the map is used in:

- a Shiny app,
- an R Markdown report,
- a vignette,
- package examples/tests.

## Testing Strategy (Minimum)

1. `spi_vis_map_data()`
- validates required columns,
- handles year selection,
- returns one row per country.

2. `spi_vis_hover_text()`
- includes country and value in labels,
- handles `NA` values correctly.

3. `spi_vis_world_map()`
- errors clearly when render columns are missing,
- returns a plotly object when inputs are valid.

4. `spi_index_map()`
- smoke test for end-to-end flow with mocked `spi_index()` data.

## Next Steps

1. Implement `spi_vis_map_data()` and tests.
2. Implement `spi_vis_hover_text()` and tests.
3. Implement `spi_vis_world_map()` with optional plot dependency checks.
4. Implement `spi_index_map()` wrapper.
5. Add roxygen docs and one vignette usage example.
6. Integrate in Shiny page via `renderPlotly(spi_index_map(...))`.
