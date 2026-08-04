---
date: 2026-07-29
updated: 2026-07-30
title: "Porting SPI_viz ggplot functions into spiR under WB style guidelines"
status: decided
supersedes: 2026-07-23-visualization-functions-and-spi-map.md
chosen-approach: "7 spi_plot_* ggplot functions fed by spi_index()/spi_data()/country_info(), generalized to index/pillar/dimension/indicator, WB Official Boundaries via ArcGIS API + cache, ggiraph for map interactivity (toggle), raw column names as labels for v1, viz deps in Suggests"
tags: [visualization, ggplot2, wbplot, ggiraph, map, spi-index, country-info, pillars, dimensions, indicators, regions, population-weighting, api-design]
---

# Porting SPI_viz ggplot Functions into spiR

## Context

The visualization prototypes now live **inside this repo** under
[viz_functions/](../../viz_functions), added by the author as the canonical set
of charts to port into `spiR`. There are **seven** working ggplot functions
(the earlier brainstorm assumed five):

| # | File | Function |
| - | ---- | -------- |
| 1 | `1. map_any_ggplot.R` | `create_spimap_col()` (+ `create_spimap()` shortcut) |
| 2 | `2. timeseries_pillar_by_country_ggplot.R` | `create_pillars_by_country()` |
| 3 | `3. timeseries_pillar_comparison_ggplot.R` | `create_pillar_comparison()` |
| 4 | `4. timeseries_country_vs_region_ggplot.R` | `create_country_vs_region()` |
| 5 | `5. pillar_performance_ggplot.R` | `create_pillar_performance()` (radar) |
| 6 | `6. timeseries_region_ggplot.R` | `create_region_comparison()` |
| 7 | `7. timeseries_pillar_by_region_ggplot.R` | `create_pillars_by_region()` |

They read data via the package API already (`spi_index()`, and
`country_info()` for region/population/income), with a fallback that sources a
`functions/` folder while `spiR` is not installed. They hardcode World Bank
Data Viz Style Guide hex colours and use `theme_minimal()`. The goal is to
bring them into `spiR` as stable, documented functions for external users.

This document refines and supersedes the 2026-07-23 brainstorm (which assumed a
`plotly` wrapper fed by CSV) and updates the 2026-07-29 first pass (which
assumed five functions including a lollipop). The direction is confirmed:
**ggplot-based**, following **World Bank style guidelines** (via `wbplot`).

## Scope / Audience

These functions are **part of the public `spiR` package API for external users**
who install the library and want to visualize SPI data in their own R
sessions, scripts, R Markdown reports, or pkgdown sites. They are **not** built
for the SPI website nor for the internal Shiny app. Any web/Shiny usage is out
of scope for this work: the app and site keep their own visualization layer.
The design goal is a clean, documented, standalone charting API that anyone
using `spiR` can call directly.

## Chart Catalogue (7 functions)

1. **Map** — world choropleth of any SPI column for one year, with
   highlight/zoom modes and an interactive toggle.
2. **Pillars by country** — the 5 pillar trajectories over time for one country.
3. **Trend (multi-country)** — any SPI column over time, one line per country.
4. **Country vs region** — one column over time: country vs its regional average.
5. **Radar** — the 5 pillars for a country vs its regional average, one year.
6. **Regions** — any SPI column over time, one line per WB region (averages).
7. **Region pillars** — the 5 pillars over time for a region, population-weighted.

**Dropped:** the lollipop (`create_pillar_lollipop`) is **out of scope** — it
is not part of the ported set.

## Requirements

1. Functions return `ggplot`/`ggiraph` objects that library users can compose
   and reuse in R Markdown, vignettes, pkgdown, and scripts (not tied to any
   web/Shiny front-end).
2. Follow WB Data Viz Style Guide via `wbplot` (`theme_wb()`, `WBCOLORS`,
   `scale_*_wb_d/c()`), replacing hardcoded hex and `theme_minimal()`.
3. Data comes from package functions (`spi_index()`, `spi_data()`,
   `country_info()`), never CSV.
4. Charts generalize beyond the overall SPI index to **pillars, dimensions,
   and indicators** (map, trend, country-vs-region, regions accept any column).
5. Missing values handled explicitly (no silent fallbacks); the `-99` sentinel
   is converted to `NA`; no-data countries stay visible with neutral colour +
   "No data" hover on the map.
6. Argument patterns stay consistent with existing package functions
   (`version`, `country`, `year`, `pillar`, `dimension`).
7. Map uses **WB Official Boundaries** (not `rnaturalearth`).
8. Visualization dependencies must not bloat the base install.

## Decisions

### D1 — Map data source: auto-detect from `value_col` (Option A)

A single high-level entry point auto-selects the underlying data function based
on the requested `value_col`:

- `value_col` starting with `SPI.INDEX` (e.g. `"SPI.INDEX"`, `"SPI.INDEX.PIL2"`)
  → fetch via `spi_index()`.
- Any other SPI column (e.g. `"SPI.D2.1"`, dimension/indicator columns)
  → fetch via `spi_data()`.

This keeps the user-facing call simple:

```r
spi_plot_map(value_col = "SPI.INDEX")        # overall index
spi_plot_map(value_col = "SPI.INDEX.PIL2")   # pillar 2
spi_plot_map(value_col = "SPI.DIM2.1.INDEX") # dimension 2.1
spi_plot_map(value_col = "SPI.D2.1.GDDS")    # indicator
```

Internally the pipeline still separates data prep from rendering so each layer
stays testable.

### D2 — Geometry: WB Official Boundaries via ArcGIS REST API (+ cache)

The current prototype reads a **local zip** through GDAL's `/vsizip/` virtual
filesystem (`WB_GAD_ADM0.shp` inside
`World Bank Official Boundaries - Admin 0.zip`). For the **package** this is
replaced by the ArcGIS REST API + local cache, so `spiR` does not ship a large
shapefile and stays current. The World Bank hosts its official boundaries on an
ArcGIS Online FeatureServer; the admin-0 layer matches the prototype shapefile
(`WB_GAD_ADM0.shp`):

- Base org: `https://services.arcgis.com/iQ1dY19aHwbSDYIF/arcgis/rest/services`
- Admin-0 service: `WB_GAD_ADM0/FeatureServer/0`
- GeoJSON query endpoint:
  ```
  https://services.arcgis.com/iQ1dY19aHwbSDYIF/arcgis/rest/services/WB_GAD_ADM0/FeatureServer/0/query?where=1%3D1&outFields=*&f=geojson
  ```
- Related official layers also available: `World_Bank_Official_Boundaries_World_Country_Polygons_(Very_High_Definition)`,
  `WB_GAD_Medium_Resolution`, `World_Bank_Official_Boundaries__World_Disputed_Borders`.

Plan:

1. Fetch boundaries from the ArcGIS GeoJSON endpoint via `sf::st_read()` /
   `httr2`.
2. **Cache locally** using the same pattern as the SPI inventory cache
   (`spi-inventory-cache.R`) so the map does not re-download every call and
   works offline after first fetch.
3. Provide `spi_clear_cache()`-style invalidation (reuse existing cache infra).
4. Fail loudly if the endpoint is unreachable and no cache exists.

The prototype's ISO3/name column auto-detection (`ISO_A3`/`WB_A3`/… and
`NAM_0`/`WB_NAME`/…) is preserved so the join is robust to the exact field
names returned by the API.

**Decided:** default resolution is **medium** (`WB_GAD_Medium_Resolution` /
medium admin-0), lighter for a world choropleth; allow override to very-high
definition.

### D3 — Map interactivity: `ggiraph`, with an `interactive` toggle

Stay in the ggplot ecosystem. `spi_plot_map()` exposes `interactive = TRUE`
(default), returning a `girafe` widget built from
`ggiraph::geom_sf_interactive(tooltip = ...)` + `girafe()`; `interactive =
FALSE` returns a plain `ggplot`. This preserves `theme_wb()` and all wbplot
styling, unlike plotly which breaks the ggplot paradigm.

### D4 — Dependencies in `Suggests` (confirmed)

`sf`, `ggiraph`, `wbplot`, `tidyr`, and `ggplot2` visualization extras go in
`Suggests`, not `Imports`. Each plot function guards with
`rlang::check_installed(...)` (or `requireNamespace`) and errors clearly if a
viz package is missing. Base `spiR` install stays lightweight; only viz users
pull the heavy geospatial stack.

### D5 — Include the radar chart (confirmed)

`spi_plot_radar()` is included despite the WB style guide discouraging radar
charts. It ships with a `@note` about its limitations. The prototype relies on a
custom `coord_radar()` (a `CoordPolar` with straight sides) — port it as an
internal helper.

### D6 — Naming: `spi_plot_*` prefix, 7 functions (approved)

| Existing (`viz_functions/`)          | New in `spiR`                  |
| ------------------------------------ | ------------------------------ |
| `create_spimap_col()` / `create_spimap()` | `spi_plot_map()`          |
| `create_pillars_by_country()`        | `spi_plot_pillars()`           |
| `create_pillar_comparison()`         | `spi_plot_trend()`             |
| `create_country_vs_region()`         | `spi_plot_country_vs_region()` |
| `create_pillar_performance()`        | `spi_plot_radar()`             |
| `create_region_comparison()`         | `spi_plot_regions()`           |
| `create_pillars_by_region()`         | `spi_plot_region_pillars()`    |

Rationale: autocomplete `spi_plot_` surfaces the whole chart catalogue.

### D7 — Labels: raw column names for v1 (confirmed)

Titles, legends, and axis labels use the **raw column names exactly as they
appear in the data** (`SPI.INDEX`, `SPI.INDEX.PIL1`, `SPI.DIM2.1.INDEX`,
`SPI.D2.1.GDDS`, ...). **This changes the prototypes**, which currently hardcode
friendly labels (`"Pillar 1: Data Use"`, `pillar_labels`, `pillar_short`,
`region_short`) — those lookup tables are **removed** during the port. Short
region codes (`LAC`, `SSA`, ...) as *input* aliases may be kept as a
convenience, but the *displayed* label is the raw value. Metadata-driven
human-readable labels are deferred until the `metadata()` functions are in
production, at which point plots can cross with metadata to enrich
titles/legends. This keeps the viz layer decoupled from metadata for now.

### D8 — Region/population/income from `country_info()` + population weighting (confirmed)

`spi_plot_country_vs_region()`, `spi_plot_radar()`, `spi_plot_regions()`, and
`spi_plot_region_pillars()` require region (and, for weighting, population)
metadata. Source it from **`country_info()`**, joined to the SPI table on
`iso3c` + `date` (as the prototypes already do). `spi_plot_region_pillars()`
supports a **population-weighted** average (default, `weighted = TRUE`) and a
simple unweighted mean (`weighted = FALSE`). Fail loudly if required metadata
columns are absent.

### D9 — Value scale auto-detection: 0–1 vs 0–100 (confirmed)

Index and pillar columns are scored 0–100; dimensions and indicators are shares
0–1. Charts detect the scale from the data (`max(value) <= 1` → share) and set
`y`/fill limits and rounding accordingly. Formalize this as a shared internal
helper so every chart applies the same rule consistently.

### D10 — `-99` sentinel → `NA` (confirmed)

`-99` is a missing-data sentinel in the SPI columns. Every chart converts
`-99` to `NA` before plotting (`dplyr::na_if(value, -99)`), so sentinel values
never render as real scores. Centralize this in the shared data-prep helper.

## Layered Architecture (per chart)

Keep the layering principle, restated for ggplot + auto-fetch:

1. **Data prep (internal, testable)** — resolve the source (D1), apply the
   `-99`→`NA` rule (D10) and scale detection (D9), return a tidy table; for
   region charts, join `country_info()` metadata (D8).
2. **Hover/label prep (internal, map only)** — adds `tooltip` with country +
   formatted value + "No data" handling.
3. **Geometry join (internal, map only)** — join tidy values to cached WB
   boundaries (D2) on `iso3`.
4. **Render (exported)** — builds the `ggplot` + `theme_wb()` +
   `scale_*_wb_*()`; the map wraps in `girafe()` when `interactive = TRUE`.

Non-map charts follow the same split (data prep → render) and return plain
`ggplot` objects.

## Error and Missing-Data Policy

1. Unknown/absent `value_col` → `stop()` with a clear message listing valid
   columns.
2. Selected year has no rows → `stop()`.
3. `value` is `NA` (including former `-99`) → on the map the country stays
   visible in no-data grey with a "No data" tooltip; on line charts the gap is
   shown (no interpolation across missing years).
4. Unknown country/region → `stop()` (single selection) or warn-and-skip
   (multi-selection comparisons), matching current prototype behaviour.
5. Missing region/population metadata for a requested aggregation → `stop()`.
6. Boundaries endpoint unreachable and no cache → `stop()` (fail loudly).

## WB Style Rules (from cg-skill-r-visualization)

- `theme_wb(chartType = ...)` on every chart (replace `theme_minimal()`).
- Source goes in `caption`, never `subtitle`.
- `WBCOLORS$...` for single-colour fills; `scale_*_wb_d()` for mapped
  categorical aesthetics (pillars, countries, regions);
  `scale_fill_wb_c(palette = "seq")` for the choropleth (replace the hardcoded
  `wb_seq_good` gradient).
- `geom_line(lineend = "round")`; bar width `0.66`.
- Aggregate data before ggplot; `ggsave(dpi = 300)`.

## Testing Strategy (Minimum)

1. **Shared data-prep helper** — routes to `spi_index()` vs `spi_data()` by
   `value_col`; converts `-99`→`NA` (D10); detects 0–1 vs 0–100 scale (D9);
   validates columns; year selection.
2. **`country_info()` join helper** — attaches region/population; fails loudly
   when metadata is missing; weighted vs unweighted aggregation (D8).
3. **Boundary fetch/cache** — writes cache, reads cache, fails loudly with no
   network + no cache (mock `httr2`/`sf`).
4. **`spi_plot_map()`** — errors on missing render columns; highlight vs zoom
   modes; `interactive = TRUE` returns `girafe`, `FALSE` returns `ggplot`.
5. **Each non-map `spi_plot_*()`** — smoke test returning a `ggplot` with
   mocked `spi_index()`/`spi_data()`/`country_info()`; multi-selection
   warn-and-skip behaviour.

## Next Steps

1. Add `sf`, `ggiraph`, `wbplot`, `tidyr` to `Suggests` in `DESCRIPTION`.
2. Create `R/spi-plot-map.R` with the shared data-prep helper, hover helper,
   boundary fetch/cache, and `spi_plot_map()`.
3. Port the six non-map charts into `R/spi-plot-*.R`, swapping `theme_minimal()`
   + hardcoded hex for `wbplot`, and **removing the friendly-label lookup
   tables** in favour of raw column names (D7).
4. Extract the `-99`→`NA` (D10), scale-detection (D9), and `country_info()`
   join (D8) logic into shared internal helpers.
5. Roxygen docs + one vignette example per chart.
6. testthat coverage per the strategy above.

(Out of scope: the lollipop chart; wiring these into the SPI website or the
internal Shiny app — those keep their own visualization layer.)

## Resolved Questions

1. **Chart count** → **7** functions; the lollipop is **dropped**.
2. **Labels** → **raw column names** for v1; friendly-label lookup tables in the
   prototypes are removed. Metadata-driven labels deferred to `metadata()`.
3. **Map geometry** → **ArcGIS API + cache** (not the prototype's local zip);
   default resolution **medium**, override to VHD.
4. **Region/population source** → **`country_info()`**, with population-weighted
   averages for `spi_plot_region_pillars()`.
5. **Cross-cutting behaviours formalized** → scale auto-detection (0–1 vs
   0–100), `-99`→`NA`, and the map `interactive` toggle are all first-class
   decisions (D9, D10, D3).
6. **Column naming for value_col** → use raw column names exactly as present;
   routing and error messages list the actual columns in the fetched table.
