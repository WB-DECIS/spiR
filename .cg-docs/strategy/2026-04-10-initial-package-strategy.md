---
date: 2026-04-10
title: "Initial package strategy — MVP output data, then inventory & raw data"
trigger: "new-project"
outcome: "roadmap-updated"
---

# Strategy Session: Initial Package Strategy

## Context at Session Start

- **Project**: spiR — R package for World Bank Statistical Performance Indicators data
- **Charter**: Existed with objective, key deliverables, and constraints defined
- **Roadmap**: None — no roadmap.json existed
- **Existing code**: Skeleton placeholder functions in `R/spi-data.R` (spi_get, spi_versions, spi_inventory)
- **Project type**: R package (data.table-collapse dialect)

## Discussion Summary

The user wants a focused R package that:

1. **Core output data (MVP)**: `spi_get()` retrieves the three main output files from `03_output_data/` in the worldbank/SPI GitHub repo — `SPI_data.csv`, `SPI_index.csv`, and aggregates (country + regional). Filtering by country, year, pillar, dimension built in. Default branch is `master`. Users can specify alternative versions (branches).

2. **Interactive inventory**: Due to the large number of subfolders in `01_raw_data/` (22 indicator folders across 5 pillars + metadata/misc/previous_vintages), a guided discovery function is critical. Should be menu-driven in interactive sessions (pillar → dimension → files) and return a filterable data.table in scripts.

3. **Raw data retrieval**: Fetch any raw data file by path or selection from inventory. Some files are `.xlsx`, so `readxl` is needed (not `openxlsx`).

Key facts discovered about the SPI repo:
- Default branch is `master`, not `main`
- `01_raw_data/` has 22 indicator subfolders + metadata, misc, previous_vintages
- Some subfolders are dense (4.1_SOCS: 30+ CSVs), others nearly empty (1.1_DUNL: only ignore.md)
- `3_DP` has year-based subfolders (2004–2024), not flat CSVs
- `03_output_data/` has ~15 files (CSV + XLSX) plus a misc subfolder
- No hard dependency ordering between features — can be built independently
- Inventory should be cached locally with a refresh mechanism

## Proposed Changes

Three milestones:
1. **Output Data Access (MVP)** — 6 features: download engine, spi_get(), filtering, spi_versions(), package infra, tests
2. **Inventory & Raw Data** — 6 features: tree crawler, cache system, interactive inventory, programmatic inventory, spi_get_raw(), tests
3. **Documentation & Release** — 4 features: README, vignette, R CMD check, distribution

## Decision

User approved the proposed structure with one modification: use `readxl` (not `openxlsx`) for Excel files in Milestone 2. Roadmap created as `roadmap.json` with all 16 features across 3 milestones.

## Charter Updates

Current Focus updated to reflect the approved MVP-first strategy.
