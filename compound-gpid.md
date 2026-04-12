---
last-reviewed: 2026-04-10
---

# spiR: Statistical Performance Indicators Data Package

## Objective

Build a lightweight R package for the World Bank's Statistical Performance Indicators (SPI) data. It focuses on data access, primarily the final SPI data and index data from GitHub, but also allows access to other key raw data and output data. The package prioritizes user-friendly inventory functions that make it easy to discover and specify data (especially raw or output data, not standard SPI or SPI index data). It limits dependencies, works with data.table, and is well documented and tested.

## Key Deliverables

- Core data access functions for SPI final data, index data, raw data, and output data from GitHub
- User-friendly inventory/discovery functions to browse and filter available datasets
- Minimal dependency footprint with data.table as primary data manipulation backend
- Comprehensive roxygen2 documentation for all exported functions
- Test coverage >80% with testthat (normal cases, edge cases, error conditions)
- README with setup, usage examples, and data source documentation

## Constraints

- Must work with data.table for performance and consistency
- Minimize external dependencies (prefer base R or lightweight packages)
- Data sourced from GitHub (https://github.com/worldbank/SPI); must handle network access gracefully
- SPI versions map to Git branches; package must support version selection
- Critical outputs: SPI_data.csv and SPI_index.csv; aggregates must be accessible
- Aligned with World Bank data standards and naming conventions
- Package must pass R CMD check with no warnings or errors

## Current Focus

Milestone 1 — Output Data Access (MVP): Build `spi_get()` to retrieve SPI_data.csv, SPI_index.csv, and aggregates from GitHub with filtering (country, year, pillar, dimension) and version/branch support. Set up package infrastructure and tests.
