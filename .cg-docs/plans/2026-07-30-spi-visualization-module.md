---
date: 2026-07-30
title: "Implementacion de funciones de visualizacion spi_plot_*"
status: active
scope: "Standard"
phases: 5
brainstorm: "2026-07-29-viz-ggplot-wb-guidelines-port"
language: "R"
estimated-effort: "large"
deviation-policy: "ask"
tags: [visualization, ggplot2, wbplot, ggiraph, sf, map, country-info, testthat]
---

# Plan: Implementacion de funciones de visualizacion en spiR

## Objetivo
Implementar y exportar 7 funciones de visualizacion publicas bajo el prefijo
spi_plot_*, alineadas con el brainstorm aprobado y con las convenciones del
paquete spiR.

## Alcance
- In scope:
  - spi_plot_map
  - spi_plot_pillars
  - spi_plot_trend
  - spi_plot_country_vs_region
  - spi_plot_radar
  - spi_plot_regions
  - spi_plot_region_pillars
  - helpers internos compartidos para fetch, normalizacion y escala
  - cache de geometria WB para mapas
  - pruebas unitarias y docs roxygen
- Out of scope:
  - lollipop chart
  - integracion con Shiny o website SPI
  - etiquetas semanticas via metadata (se mantiene nombre crudo de columna)

## Requisitos funcionales
1. Las funciones deben aceptar columnas SPI crudas (ej: SPI.INDEX, SPI.INDEX.PIL1, SPI.DIM2.1.INDEX, SPI.D2.1.GDDS).
2. Mapas con fronteras oficiales WB via ArcGIS API y cache local.
3. Mapas con interactive toggle: ggplot estatico o girafe.
4. Conversion explicita de -99 a NA.
5. Deteccion de escala 0-1 vs 0-100 en funciones generales.
6. Join con country_info para region/poblacion/income cuando aplique.
7. Errores fail-loudly con cli::cli_abort.

## Phase 1: Dependencias y scaffolding
- Files:
  - DESCRIPTION
- Cambios:
  - Agregar sf, ggiraph, wbplot en Suggests.
  - Mantener Imports sin dplyr/tidyr para respetar estilo data.table.
- Criterio de salida:
  - Dependencias listas y sin romper check basico.

## Phase 2: Helpers compartidos
- Files:
  - R/spi-plot-helpers.R (nuevo)
- Funciones internas:
  - .spi_plot_check_deps(pkgs)
  - .spi_plot_fetch(value_col, version, country, year)
  - .spi_plot_scale(values)
  - .spi_plot_join_meta(dt, version, cols)
- Criterio de salida:
  - Helpers cubiertos por pruebas unitarias con mocks.

## Phase 3: Mapa
- Files:
  - R/spi-plot-map.R (nuevo)
- Funciones:
  - .spi_geo_cache_dir
  - .spi_geo_cache_path
  - .spi_geo_read_cache
  - .spi_geo_write_cache
  - .spi_fetch_boundaries
  - .spi_map_hover
  - spi_plot_map
  - spi_clear_geo_cache
- Criterio de salida:
  - spi_plot_map devuelve girafe cuando interactive=TRUE y ggplot cuando FALSE.

## Phase 4: Seis charts no-mapa
- Files nuevos:
  - R/spi-plot-pillars.R
  - R/spi-plot-trend.R
  - R/spi-plot-country-vs-region.R
  - R/spi-plot-radar.R
  - R/spi-plot-regions.R
  - R/spi-plot-region-pillars.R
- Criterio de salida:
  - Cada funcion retorna ggplot y respeta nombres crudos de columnas.

## Phase 5: Testing, docs y validacion
- Files:
  - tests/testthat/test-spi-plot-helpers.R
  - tests/testthat/test-spi-plot-map.R
  - tests/testthat/test-spi-plot-geo-cache.R
  - tests/testthat/test-spi-plot-pillars.R
  - tests/testthat/test-spi-plot-trend.R
  - tests/testthat/test-spi-plot-country-vs-region.R
  - tests/testthat/test-spi-plot-radar.R
  - tests/testthat/test-spi-plot-regions.R
  - tests/testthat/test-spi-plot-region-pillars.R
  - NAMESPACE
  - man/*.Rd (generados)
- Validacion:
  - roxygen2::roxygenise
  - testthat enfocado en nuevos tests
  - suite completa de tests
- Criterio de salida:
  - Nuevas funciones exportadas, tests verdes, docs generadas.

## Estrategia de pruebas
- Usar test_that como patron principal.
- Fixtures en data.table.
- Mocks con local_mocked_bindings para evitar red.
- Para dependencias opcionales: skip_if_not_installed en tests de viz.

## Riesgos y mitigacion
- API ArcGIS no disponible:
  - Mitigacion: cache local + error claro si no hay cache.
- Cambios de esquema en columnas de boundaries:
  - Mitigacion: autodeteccion robusta de ISO3 y nombre de pais.
- Diferencias de escala entre columnas:
  - Mitigacion: helper unico de deteccion de escala.

## Entregables
1. 7 funciones spi_plot_* exportadas.
2. Cache de geometria WB con limpieza dedicada.
3. Cobertura de pruebas para rutas nominales y errores.
4. Documentacion roxygen y man pages.
