# 🧠 Project Brain — Chronological Log

_Generated 2026-07-13 · 27 artifacts (newest first) + 16 roadmap features_

## undated

- **[2026-04-10-milestone-1-output-data-mvp-review](.cg-docs/reviews/2026-04-10-milestone-1-output-data-mvp-review.md)** · `review` · _—_ · `—`
  > **Review depth**: standard **Files reviewed**: 15 (R/spi-download.R, R/spi-filters.R, R/spi-data.R, R/spi-wrappers.R,…
- **[2026-04-11-inventory-cache-system-review](.cg-docs/reviews/2026-04-11-inventory-cache-system-review.md)** · `review` · _—_ · `—`
  > **Review depth**: standard **Files reviewed**: 4 (`R/spi-inventory-cache.R`, `tests/testthat/test-spi-inventory-cache…
- **[2026-04-12-documentation-release-milestone-review](.cg-docs/reviews/2026-04-12-documentation-release-milestone-review.md)** · `review` · _—_ · `—`
  > **Changed files reviewed:** - `.gitignore` (modified) - `DESCRIPTION` (modified — version 0.1.0, 4 new Suggests) - `N…
- **[2026-04-12-inventory-cache-system-review](.cg-docs/reviews/2026-04-12-inventory-cache-system-review.md)** · `review` · _—_ · `—`
  > **Review depth**: standard **Files reviewed**: 4 (`R/spi-inventory-cache.R`, `R/spi-filters.R`, `R/spi-github.R`, `te…

## 2026-07-13

- **[2026-07-10-metadata-api-review](.cg-docs/reviews/2026-07-10-metadata-api-review.md)** · `review` · _—_ · `2026-07-13`
  > **Review mode**: standard **Files reviewed**: 10 **Findings**: 9 (P0: 1, P1: 1, P2: 5, P3: 2)
- **[2026-07-10-metadata-api-verify-review](.cg-docs/reviews/2026-07-10-metadata-api-verify-review.md)** · `review` · _—_ · `2026-07-13`
  > **Review mode**: light **Files reviewed**: 12 **Findings**: 4 (P0: 1, P1: 1, P2: 1, P3: 1)
- **[Metadata hierarchy deduplication must use stable keys, not descriptive text](.cg-docs/solutions/data-quality/2026-07-13-metadata-hierarchy-dedup-prevents-false-extra-pillars.md)** · `solution` · _—_ · `2026-07-13`
  > `metadata_pillars()` surfaced an apparent sixth pillar even though the SPI metadata source only has five pillar keys.…

## 2026-07-10

- **[SPI Metadata API](.cg-docs/plans/2026-07-10-metadata-api.md)** · `plan` · _active_ · `2026-07-10`
  > Add a `metadata()` function and two wrappers — `metadata_pillars()` and `metadata_dimensions()` — that let users expl…

## 2026-06-25

- **[2026-06-25-country-info-review](.cg-docs/reviews/2026-06-25-country-info-review.md)** · `review` · _—_ · `2026-06-25`
  > **Review mode**: standard **Files reviewed**: 6 **Findings**: 5 (P0: 0, P1: 1, P2: 2, P3: 2)
- **[Country Info Metadata Wrapper](.cg-docs/plans/2026-06-25-country-info.md)** · `plan` · _completed_ · `2026-06-25`
  > Add a dedicated API for retrieving country-year metadata columns from the SPI data, such as ISO codes, country name, …

## 2026-06-12

- **[SPI Indicator Selection](.cg-docs/plans/2026-06-12-spi-indicator-selection.md)** · `plan` · _active_ · `2026-06-12`
  > Add a dedicated API for requesting named SPI indicator columns directly, such as `SPI.D1.5.POV` or `SPI.D2.1.GDDS`, t…

## 2026-04-12

- **[Case-sensitive ISO3C filter silently returns 0 rows when user passes lowercase codes](.cg-docs/solutions/data-quality/2026-04-12-country-code-case-sensitivity-silent-empty-filter.md)** · `solution` · _—_ · `2026-04-12`
  > A user calls a data-access function with lowercase or mixed-case country codes: The function returns an empty `data.t…
- **[data.table melt\(\) returns factor variable column by default, requiring redundant as.character\(\) coercion](.cg-docs/solutions/performance-issues/2026-04-12-melt-variable-factor-default-anti-pattern.md)** · `solution` · _—_ · `2026-04-12`
  > When reshaping a `data.table` from wide to long with `melt()`, the `variable` column (controlled by `variable.name`) …
- **[Documentation & Release — Milestone 3 implementation](.cg-docs/plans/2026-04-12-documentation-release-milestone.md)** · `plan` · _completed_ · `2026-04-12`
  > Finalize the spiR package for public use by writing a comprehensive vignette (data access, analysis, visualization wi…
- **[Documentation & Release — Milestone 3 planning](.cg-docs/brainstorms/2026-04-12-documentation-release-milestone.md)** · `brainstorm` · _decided_ · `2026-04-12`
  > <!-- Valid status values: decided, in-progress, abandoned -->
- **[ggplot2 reorder\(\) and data.table setorder\(\) silently misbehave when the sort column contains NA](.cg-docs/solutions/data-quality/2026-04-12-na-unsafe-reorder-setorder-on-score-columns.md)** · `solution` · _—_ · `2026-04-12`
  > SPI score columns (`SPI.INDEX`, `SPI.INDEX.PIL1`–`PIL5`) are `NA` for country-years where data is unavailable. Two co…
- **[pkgdown GitHub Actions deploy fires on PRs without an if: guard, causing permissions errors and dirty gh-pages history](.cg-docs/solutions/git-workflows/2026-04-12-pkgdown-gha-deploy-fires-on-prs.md)** · `solution` · _—_ · `2026-04-12`
  > A pkgdown GitHub Actions workflow with the following structure: causes two failure modes: 1. **Fork PRs** → the ephem…
- **[renv::snapshot\(\) cascades to hundreds of uninstalled Suggests when package.dependency.fields includes 'Suggests'](.cg-docs/solutions/environment-issues/2026-04-12-renv-snapshot-suggests-cascade-failure.md)** · `solution` · _—_ · `2026-04-12`
  > After adding `"Suggests"` to `package.dependency.fields` in `renv/settings.json` to capture an R package's own Sugges…

## 2026-04-11

- **[Hand-written INI-format renv.lock blocks all renv operations](.cg-docs/solutions/environment-issues/2026-04-11-renv-lock-ini-format-breaks-all-renv-operations.md)** · `solution` · _—_ · `2026-04-11`
  > All `renv` operations (`renv::snapshot()`, `renv::init()`, `renv::restore()`) fail immediately with:
- **[Inventory cache system](.cg-docs/plans/2026-04-11-inventory-cache-system.md)** · `plan` · _completed_ · `2026-04-11`
  > Build a persistent on-disk cache layer that stores the crawled GitHub file tree for each SPI version (branch). The ca…
- **[Inventory cache system — per-version RDS with enriched metadata](.cg-docs/brainstorms/2026-04-11-inventory-cache-system.md)** · `brainstorm` · _decided_ · `2026-04-11`
  > Milestone 2 ("Inventory & Raw Data") requires a cache layer for the GitHub file tree so that `spi_inventory()` and `s…
- **[Mock a package-private .function\(\) helper to test functions that delegate HTTP](.cg-docs/solutions/testing-patterns/2026-04-11-mock-private-http-helper-instead-of-http-primitives.md)** · `solution` · _—_ · `2026-04-11`
  > `spi_versions()` originally called `readLines(url)` to fetch JSON from the GitHub API and parsed it with regex. Tests…
- **[Mock an imported function in the package's own namespace, not the source package](.cg-docs/solutions/testing-patterns/2026-04-11-mock-imported-function-in-package-namespace.md)** · `solution` · _—_ · `2026-04-11`
  > A test tried to mock `fread` to make it throw an error, but the mock had no effect and the real `fread` ran instead: …

## 2026-04-10

- **[data.table S3 dispatch fails inside package namespace without @importFrom](.cg-docs/solutions/bugs/2026-04-10-datatable-s3-dispatch-fails-without-namespace-import.md)** · `solution` · _—_ · `2026-04-10`
  > `[.data.table` S3 dispatch fails silently when `data.table` is listed in `Imports:` in `DESCRIPTION` but **not import…
- **[Initial package strategy — MVP output data, then inventory & raw data](.cg-docs/strategy/2026-04-10-initial-package-strategy.md)** · `strategy` · _—_ · `2026-04-10`
  > - **Project**: spiR — R package for World Bank Statistical Performance Indicators data - **Charter**: Existed with ob…
- **[Milestone 1 API design — spi_get\(\) with convenience wrappers](.cg-docs/brainstorms/2026-04-10-milestone-1-api-design.md)** · `brainstorm` · _decided_ · `2026-04-10`
  > Milestone 1 (Output Data Access MVP) needs a clear public API for retrieving the three core SPI output files from the…
- **[Milestone 1 — Output Data Access MVP](.cg-docs/plans/2026-04-10-milestone-1-output-data-mvp.md)** · `plan` · _active_ · `2026-04-10`
  > Implement the full Milestone 1 deliverable: users can retrieve SPI_data.csv, SPI_index.csv, and regional aggregates f…

## Roadmap Features

- **[Filtering in spi_get\(\)](roadmap.json#filtering-in-spi-get)** · `feature` · _done_ · `—`
  > Filtering in spi_get()
- **[GitHub download engine](roadmap.json#github-download-engine)** · `feature` · _done_ · `—`
  > GitHub download engine
- **[GitHub tree crawler](roadmap.json#github-tree-crawler)** · `feature` · _idea_ · `—`
  > GitHub tree crawler
- **[Inventory cache system](roadmap.json#inventory-cache-system)** · `feature` · _idea_ · `—`
  > Inventory cache system
- **[Package infrastructure](roadmap.json#package-infrastructure)** · `feature` · _done_ · `—`
  > Package infrastructure
- **[pkgdown site or GitHub release](roadmap.json#pkgdown-site-or-github-release)** · `feature` · _idea_ · `—`
  > pkgdown site or GitHub release
- **[R CMD check zero warnings](roadmap.json#r-cmd-check-zero-warnings)** · `feature` · _idea_ · `—`
  > R CMD check zero warnings
- **[README with examples](roadmap.json#readme-with-examples)** · `feature` · _idea_ · `—`
  > README with examples
- **[spi_get\(\) for big three](roadmap.json#spi-get-for-big-three)** · `feature` · _done_ · `—`
  > spi_get() for big three
- **[spi_get_raw\(\)](roadmap.json#spi-get-raw)** · `feature` · _idea_ · `—`
  > spi_get_raw()
- **[spi_inventory\(\) interactive mode](roadmap.json#spi-inventory-interactive-mode)** · `feature` · _idea_ · `—`
  > spi_inventory() interactive mode
- **[spi_inventory\(\) programmatic mode](roadmap.json#spi-inventory-programmatic-mode)** · `feature` · _idea_ · `—`
  > spi_inventory() programmatic mode
- **[spi_versions\(\)](roadmap.json#spi-versions)** · `feature` · _done_ · `—`
  > spi_versions()
- **[Tests for Milestone 1](roadmap.json#tests-for-milestone-1)** · `feature` · _done_ · `—`
  > Tests for Milestone 1
- **[Tests for Milestone 2](roadmap.json#tests-for-milestone-2)** · `feature` · _idea_ · `—`
  > Tests for Milestone 2
- **[Vignette: SPI data workflows](roadmap.json#vignette-spi-data-workflows)** · `feature` · _idea_ · `—`
  > Vignette: SPI data workflows
