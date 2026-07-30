---
date: 2026-07-30
title: "Implementacion completa del modulo de visualizacion spi_plot_*"
status: active
completed-phases: []
current-phase: 1
failing-steps: []
scope: "Standard"
phases: 3
brainstorm: ".cg-docs/brainstorms/2026-07-29-viz-ggplot-wb-guidelines-port.md"
language: "R"
estimated-effort: "large"
deviation-policy: "ask"
execution-report: ".cg-docs/work-reports/2026-07-30-spi-visualization-module-complete.md"
tags: [visualization, ggplot2, wbplot, ggiraph, sf, data.table, country-info, testthat]
---

# Plan: Implementacion completa del modulo de visualizacion spi_plot_*

## Objective
Implementar 7 funciones publicas de visualizacion bajo el prefijo spi_plot_* en
spiR, alineadas con el brainstorm aprobado, usando patrones del paquete
(data.table, cli fail-loudly, cache en R_user_dir) y cobertura de pruebas
unitarias.

## Context
El plan previo 2026-07-30-spi-visualization-module.md define direccion tecnica,
pero no incluye Completion Contract ni trazabilidad formal de requisitos para
cg-work. Esta version completa agrega estructura ejecutable por fases, contrato
de completitud y evidencia verificable.

## Requirements
| ID | Requirement | Source |
|----|-------------|--------|
| R1 | Exportar 7 funciones publicas: spi_plot_map, spi_plot_pillars, spi_plot_trend, spi_plot_country_vs_region, spi_plot_radar, spi_plot_regions, spi_plot_region_pillars. | Brainstorm + user request |
| R2 | Usar columnas SPI crudas como entrada (ej. SPI.INDEX, SPI.INDEX.PIL1, SPI.DIM2.1.INDEX, SPI.D2.1.GDDS). | Brainstorm decision D7 |
| R3 | Implementar mapa con fronteras oficiales WB via ArcGIS API y cache local reutilizable. | Brainstorm decision D2 |
| R4 | Implementar toggle interactive en mapa: interactive=TRUE devuelve girafe, FALSE devuelve ggplot. | Brainstorm decision D3 |
| R5 | Normalizar -99 a NA en todo el pipeline de visualizacion. | Brainstorm decision D10 |
| R6 | Auto-detectar escala 0-1 vs 0-100 para columnas generales. | Brainstorm decision D9 |
| R7 | Usar country_info() para region/poblacion/income en funciones regionales y ponderadas. | Brainstorm decision D8 |
| R8 | Errores fail-loudly con cli::cli_abort y warnings controlados con cli::cli_warn. | Project constraints |
| R9 | Mantener backend data.table (sin introducir dplyr/tidyr en Imports). | compound-gpid.local.md |
| R10 | Incluir pruebas unitarias para helpers, mapa, cache y 6 charts no-mapa, con mocks y sin dependencia de red. | Testing strategy |
| R11 | Generar documentacion roxygen y exportaciones en NAMESPACE para nuevas funciones publicas. | Package standards |
| R12 | Mantener lollipop chart fuera de alcance en esta iteracion. | Brainstorm scope |

## Phase 1: Base visualization infrastructure

### 1. Add visualization Suggests and dependency guards
- **Requirements**: R8, R9
- **Files**: DESCRIPTION
- **Details**:
  - Agregar sf, ggiraph, wbplot a Suggests.
  - Confirmar que Imports no agrega dplyr/tidyr.
  - Definir patron de check_installed/requireNamespace en helpers.
- **Test Scenarios**: dependencia instalada, dependencia faltante
- **Tests**: test-spi-plot-helpers.R
- **Acceptance criteria**: Dependencias de visualizacion quedan opcionales y los errores por dependencia faltante son claros.

### 2. Create shared internal helpers for fetch, scale, and metadata joins
- **Requirements**: R2, R5, R6, R7, R8, R9
- **Files**: R/spi-plot-helpers.R
- **Details**:
  - Implementar .spi_plot_check_deps(pkgs).
  - Implementar .spi_plot_fetch(value_col, version, country, year) con ruteo spi_index/spi_data.
  - Implementar conversion -99 -> NA y validacion de columna inexistente.
  - Implementar .spi_plot_scale(values) para 0-1 vs 0-100.
  - Implementar .spi_plot_join_meta(dt, version, cols) usando country_info().
- **Test Scenarios**: columna valida, columna inexistente, -99 sentinel, escala share/index, metadata faltante
- **Tests**: test-spi-plot-helpers.R
- **Acceptance criteria**: Helpers retornan estructuras esperadas, detectan errores y no requieren red cuando estan mockeados.

## Phase 2: Map and non-map plotting functions

### 3. Implement map geometry retrieval and cache utilities
- **Requirements**: R3, R8, R9
- **Files**: R/spi-plot-map.R
- **Details**:
  - Implementar .spi_geo_cache_dir/.spi_geo_cache_path/.spi_geo_read_cache/.spi_geo_write_cache.
  - Implementar .spi_fetch_boundaries() con ArcGIS GeoJSON + autodeteccion de iso3/nombre.
  - Reusar patron de cache tipo inventory (schema/timestamp/validacion minima).
  - Exponer spi_clear_geo_cache().
- **Test Scenarios**: cache hit, cache miss, estructura invalida, endpoint caido sin cache
- **Tests**: test-spi-plot-geo-cache.R
- **Acceptance criteria**: Geometria se reutiliza desde cache y falla con mensaje claro cuando no hay red ni cache.

### 4. Implement spi_plot_map
- **Requirements**: R1, R2, R3, R4, R5, R6, R8
- **Files**: R/spi-plot-map.R
- **Details**:
  - Implementar join data + boundaries + hover text.
  - interactive=TRUE retorna girafe; FALSE retorna ggplot.
  - Mantener paises sin datos visibles con color neutral y tooltip "No data".
- **Test Scenarios**: output interactive/static, columna invalida, year sin datos, highlight/zoom
- **Tests**: test-spi-plot-map.R
- **Acceptance criteria**: Funcion retorna clase esperada y aplica reglas de datos faltantes.

### 5. Implement six non-map plotting functions
- **Requirements**: R1, R2, R5, R6, R7, R8, R9, R12
- **Files**:
  - R/spi-plot-pillars.R
  - R/spi-plot-trend.R
  - R/spi-plot-country-vs-region.R
  - R/spi-plot-radar.R
  - R/spi-plot-regions.R
  - R/spi-plot-region-pillars.R
- **Details**:
  - Portear funciones desde viz_functions a API publica spi_plot_*.
  - Mantener nombres crudos de columnas en labels v1.
  - Incluir peso poblacional en spi_plot_region_pillars(weighted=TRUE).
  - Incluir nota de limitaciones para radar.
- **Test Scenarios**: nominal por funcion, argumentos invalidos, region/pais no encontrado, weighted vs unweighted
- **Tests**:
  - test-spi-plot-pillars.R
  - test-spi-plot-trend.R
  - test-spi-plot-country-vs-region.R
  - test-spi-plot-radar.R
  - test-spi-plot-regions.R
  - test-spi-plot-region-pillars.R
- **Acceptance criteria**: Cada funcion retorna ggplot y respeta contratos de entrada/salida definidos.

## Phase 3: Tests, documentation, and release checks

### 6. Add complete test suite for visualization module
- **Requirements**: R10
- **Files**:
  - tests/testthat/test-spi-plot-helpers.R
  - tests/testthat/test-spi-plot-geo-cache.R
  - tests/testthat/test-spi-plot-map.R
  - tests/testthat/test-spi-plot-pillars.R
  - tests/testthat/test-spi-plot-trend.R
  - tests/testthat/test-spi-plot-country-vs-region.R
  - tests/testthat/test-spi-plot-radar.R
  - tests/testthat/test-spi-plot-regions.R
  - tests/testthat/test-spi-plot-region-pillars.R
- **Details**:
  - Usar data.table fixtures y local_mocked_bindings para aislar red/deps pesadas.
  - Añadir skip_if_not_installed para Suggests de visualizacion cuando aplique.
- **Test Scenarios**: happy path, edge cases, error paths por modulo
- **Tests**: testthat::test_file por archivo nuevo + corrida agregada
- **Acceptance criteria**: Tests nuevos pasan en local sin llamadas externas reales.

### 7. Generate exports/docs and run full validation
- **Requirements**: R1, R11
- **Files**: NAMESPACE, man/*.Rd
- **Details**:
  - Ejecutar roxygen2::roxygenise.
  - Verificar export(spi_plot_*) y export(spi_clear_geo_cache).
  - Correr suite completa de tests y validar cero regresiones criticas.
- **Test Scenarios**: funciones exportadas, docs generadas, check de carga del paquete
- **Tests**: devtools::test(); validacion de NAMESPACE
- **Acceptance criteria**: Exportaciones y docs completas; test suite final en verde.

## Testing Strategy
- Patron principal: test_that.
- Fixtures: data.table helper functions por archivo.
- Mocks: local_mocked_bindings para spi_index, spi_data, country_info, boundary fetch.
- Tests de red reales solo si son estrictamente necesarios; default sin red.
- Verificar clases de retorno (ggplot, girafe) y mensajes de error/warn.

## Documentation Checklist
- [ ] Roxygen blocks completos para las 7 funciones publicas.
- [ ] @keywords internal en helpers .spi_*.
- [ ] NAMESPACE con exportaciones nuevas.
- [ ] man/*.Rd para modulo de visualizacion.
- [ ] Ejemplos minimos (y dontrun cuando implique red).

## Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| ArcGIS endpoint no disponible | Reintento via cache local; abort claro si no existe cache usable |
| Cambio de nombres de columnas en boundaries | Autodeteccion robusta de campos iso3/nombre |
| Regresiones por dependencias opcionales faltantes | Guard clauses + skip_if_not_installed en tests |
| Escalas mal interpretadas entre columnas | Helper unico .spi_plot_scale centralizado |
| Datos regionales incompletos en country_info | Validacion explicita de columnas requeridas y abort temprano |

## Out of Scope
- Lollipop chart.
- Integracion con website SPI o Shiny interno.
- Etiquetas enriquecidas por metadata() en esta iteracion.
- Rediseño de funciones core spi_get/spi_data/spi_index.

## Completion Contract

### Outcome
El paquete spiR expone un modulo de visualizacion completo con 7 funciones
spi_plot_* y utilidades asociadas, con cache de geometria para mapas, manejo de
errores fail-loudly y cobertura de pruebas reproducible.

### Verification Surface
| ID | Phase | Evidence Required | Command/Artifact | Required |
|----|-------|-------------------|------------------|----------|
| V1 | 1 | DESCRIPTION incluye sf, ggiraph, wbplot en Suggests sin agregar dplyr/tidyr a Imports | inspeccion de DESCRIPTION + test helpers | yes |
| V2 | 1 | Helpers .spi_plot_* implementados y pruebas unitarias basicas pasan | tests/testthat/test-spi-plot-helpers.R | yes |
| V3 | 2 | Cache de geometria y fetch boundaries funcionan con mocks de cache hit/miss | tests/testthat/test-spi-plot-geo-cache.R | yes |
| V4 | 2 | spi_plot_map retorna girafe o ggplot segun interactive | tests/testthat/test-spi-plot-map.R | yes |
| V5 | 2 | Las 6 funciones no-mapa retornan ggplot y validan entradas clave | tests/testthat/test-spi-plot-*.R | yes |
| V6 | 3 | Exportaciones en NAMESPACE para 7 spi_plot_* y spi_clear_geo_cache | NAMESPACE | yes |
| V7 | 3 | Man pages generadas para funciones publicas del modulo | man/*.Rd | yes |
| V8 | final | Suite de tests relevante en verde sin regresiones criticas | devtools::test() | yes |

### Constraints
| ID | Phase | Constraint | Check |
|----|-------|------------|-------|
| C1 | 1 | Mantener backend data.table; no dplyr/tidyr en Imports | DESCRIPTION + revision de archivos R/spi-plot-* |
| C2 | 2 | Errores deben usar cli::cli_abort/cli::cli_warn | revision de mensajes de error en funciones nuevas |
| C3 | 2 | Lollipop permanece fuera de alcance | ausencia de spi_plot_lollipop exportado |
| C4 | 3 | No romper wrappers existentes de datos | correr suite completa y revisar fallos de regresion |

### Boundaries
- Allowed: crear/modificar funciones R/spi-plot-*.R, tests del modulo, DESCRIPTION, NAMESPACE y man pages generadas.
- Out of scope: cambiar roadmap.json manualmente, modificar arquitectura de datos core fuera de necesidades del modulo, agregar charts no aprobados.

### Iteration Policy
1. Si una prueba nueva no falla en red-phase, registrar observacion y continuar con implementacion, luego validar resultado final.
2. Si faltan datos para un calculo requerido, fallar de forma explicita con cli::cli_abort en lugar de fallback silencioso.
3. Si una dependencia Suggests no esta instalada, abortar con mensaje accionable o skip en test segun corresponda.
4. Cualquier desviacion de alcance (ej. agregar chart extra) requiere aprobacion del usuario por politica ask.

### Blocked-Stop Conditions
- No se puede ejecutar evidencia requerida de Verification Surface.
- Fallan pruebas criticas despues de 2 intentos de fix por paso.
- Se requiere cambiar un artefacto protegido fuera de permisos del flujo.
- No se puede mantener data.table como backend en un paso sin introducir dependencias no aprobadas.
