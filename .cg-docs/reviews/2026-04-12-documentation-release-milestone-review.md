---
plan: 2026-04-12-documentation-release-milestone
review-date: 2026-04-12
depth: standard
agents: [cg-code-quality, cg-testing, cg-documentation, cg-version-control, cg-reproducibility, cg-performance, cg-architecture, cg-data-quality]
findings:
  F01: fixed
  F02: fixed
  F03: fixed
  F04: fixed
  F05: fixed
  F06: fixed
  F07: fixed
  F08: fixed
  F09: fixed
  F10: already-present
  F11: fixed
  F12: already-present
  F13: fixed
  F14: fixed
  F15: fixed
  F16: fixed
  F17: fixed
  F18: fixed
  F19: fixed
  F20: fixed
  F21: fixed
  F22: fixed
  F23: fixed
  F24: fixed
  F25: fixed
  F26: fixed
  F27: fixed
  F28: fixed
  F29: fixed
  F30: fixed
  F15: open
  F16: open
  F17: open
  F18: open
  F19: open
  F20: open
  F21: open
  F22: open
  F23: open
  F24: open
  F25: open
  F26: open
  F27: open
  F28: open
  F29: open
  F30: open
---

# Review: Documentation & Release Milestone (v0.1.0)

**Changed files reviewed:**
- `.gitignore` (modified)
- `DESCRIPTION` (modified — version 0.1.0, 4 new Suggests)
- `NEWS.md` (modified)
- `README.md` (modified — SPI explainer)
- `vignettes/spi-data-workflows.Rmd` (new)
- `_pkgdown.yml` (new)
- `.github/workflows/pkgdown.yaml` (new)

---

## P1 — Must Fix

**[F01]** [arch, testing, vc] `.github/workflows/pkgdown.yaml` — Deploy step runs on every `pull_request`  
**Why**: The `JamesIves` deploy step has no `if:` guard. On same-repo PRs this silently pushes to `gh-pages`, dirtying git history and deploying unreviewed content. On fork PRs it fails with a permissions error, generating misleading red CI.  
**Fix**:
```yaml
- name: Deploy to GitHub Pages
  if: github.event_name != 'pull_request'
  uses: JamesIves/github-pages-deploy-action@v4
```

**[F02]** [repro] `.github/workflows/pkgdown.yaml` — R version not pinned in CI  
**Why**: `r-lib/actions/setup-r@v2` with no `r-version:` always installs the latest R. `renv.lock` records `R 4.3.1`. A future R release could silently break the build.  
**Fix**:
```yaml
- uses: r-lib/actions/setup-r@v2
  with:
    r-version: "4.3.1"
    use-public-rspm: true
```

**[F03]** [repro] `renv/settings.json` — Suggests packages absent from `renv.lock`  
**Why**: `package.dependency.fields` excludes `"Suggests"`, so `testthat`, `knitr`, `rmarkdown`, `ggplot2`, and `scales` are not locked. A developer doing `renv::restore()` cannot run the test suite or build the vignette without manual installs.  
**Fix**: Add `"Suggests"` to `package.dependency.fields` in `renv/settings.json`, then run `renv::snapshot()`:
```json
"package.dependency.fields": ["Imports", "Depends", "LinkingTo", "Suggests"]
```

---

## P2 — Should Fix

### CI & Infrastructure

**[F04]** [code-quality, arch] `.github/workflows/pkgdown.yaml:14–15` — `pages: write` and `id-token: write` unnecessary  
**Why**: Those scopes are only needed for the `actions/upload-pages-artifact` + `actions/deploy-pages` pattern. The JamesIves action requires only `contents: write`. Over-provisioning the `GITHUB_TOKEN` is a security misconfiguration.  
**Fix**: Reduce to `permissions: contents: write`

**[F05]** [code-quality, vc, repro] `.github/workflows/pkgdown.yaml:43` — `JamesIves/github-pages-deploy-action@v4` not pinned to SHA  
**Why**: Mutable version tags can be re-pointed upstream, silently changing build behaviour. The same applies to `actions/checkout@v4` and `r-lib/actions/setup-r@v2`.  
**Fix**: Pin each action to an immutable commit SHA, e.g.:
```yaml
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```

**[F06]** [repro] `.github/workflows/pkgdown.yaml:18` — `ubuntu-latest` is a floating runner label  
**Why**: GitHub silently shifts `ubuntu-latest` between Ubuntu versions, changing system library versions for packages with native code (`httr2`, `curl`, `openssl`).  
**Fix**: Pin to `ubuntu-22.04`

### Package Configuration

**[F07]** [vc, arch] `.Rbuildignore` — `_pkgdown.yml` not excluded from build  
**Why**: `R CMD check` emits a NOTE for non-standard top-level files. `_pkgdown.yml` is site config and has no place in the tarball.  
**Fix**: Add `^_pkgdown\\.yml$` to `.Rbuildignore`

**[F08]** [code-quality, vc] `.gitignore` — duplicate `docs/` entry  
**Why**: `docs/` appears twice (lines ~15 and ~37). Harmless but indicates copy-paste noise.  
**Fix**: Remove the second occurrence.

**[F09]** [arch] `DESCRIPTION` — `scales (>= 1.2.0)` in Suggests has no direct call site  
**Why**: No `scales::` call exists anywhere in the vignette or tests. `ggplot2` already depends on `scales`, so it is always present. This entry is misleading.  
**Fix**: Remove `scales (>= 1.2.0)` from Suggests.

### Tests

**[F10]** [testing] `tests/testthat/test-spi-data.R` — multi-year vector filtering untested  
**Why**: The `year = c(2023L, 2024L)` code path is exercised in the vignette but has no corresponding test. Silent regression risk.  
**Fix**: Add a test covering `spi_data(year = c(2023L, 2024L))`.

**[F11]** [testing] `tests/testthat/test-spi-data.R` — multi-region filtering untested  
**Fix**: Add a test for `spi_aggregates(region = c("...", "..."))`.

**[F12]** [testing] `tests/testthat/test-spi-data.R` — `spi_get("index", pillar = n)` column-filter path untested  
**Fix**: Add a test covering `spi_get("index", pillar = 2L)` and verifying only `PIL2` columns are returned.

### Vignette Accuracy & Documentation

**[F13]** [docs] `vignettes/spi-data-workflows.Rmd:~95` — `dimension` row in filter table missing scope qualifier  
**Why**: The table doesn't clarify that `dimension` filtering only applies to `type = "data"` and not `"index"`.  
**Fix**: Add scope column or footnote: "Only applicable when `type = \"data\"`."

**[F14]** [docs] `vignettes/spi-data-workflows.Rmd` — bare integer args without `L` suffix (4+ occurrences)  
**Why**: `pillar = 3`, `year = 2024` etc. should be `3L`, `2024L` per the project's data.table/collapse R style. The vignette is the primary teaching document for style.  
**Fix**: Audit all numeric args and add `L` suffix.

**[F15]** [docs] `vignettes/spi-data-workflows.Rmd:~414` — caching description misstates granularity  
**Why**: Text implies the cache is per-call arguments; it is actually per type/version.  
**Fix**: Correct to: "Results are cached per data type and version, so repeated calls with different `country` or `year` filters draw from the same local cache."

**[F16]** [docs] `vignettes/spi-data-workflows.Rmd`, `README.md` — `spi_update_inventory()` and `spi_clear_inventory()` undocumented  
**Why**: These are public exported functions absent from the vignette workflow sections and README function table.  
**Fix**: Add a "Managing the inventory" subsection to the vignette caching section; add rows to the README function reference table.

**[F17]** [docs] `NEWS.md:~10` — 0.0.0.9000 entry missing inventory function bullets  
**Fix**: Add `* Added \`spi_update_inventory()\`` and `* Added \`spi_clear_inventory()\`` to 0.0.0.9000 section.

**[F18]** [code-quality] `vignettes/spi-data-workflows.Rmd:~259` — bare `install.packages("ggplot2")` chunk  
**Why**: This chunk will run if a user knits the file with the global `eval = FALSE` override removed. It teaches an unconditional install, conflicting with the convention to use `requireNamespace()` guards.  
**Fix**: Remove the chunk entirely or replace with `if (!requireNamespace("ggplot2", quietly = TRUE)) install.packages("ggplot2")`.

### Source Code Data Quality

**[F19]** [data] `R/spi-data.R:~97` — `country` ISO3C code not normalised for case  
**Why**: The filter is case-sensitive. `spi_get(country = "nor")` silently returns 0 rows. Nothing warns the user.  
**Fix**: `country <- toupper(trimws(country))` before the filter. Document in `@param country`.

**[F20]** [data] `R/spi-data.R:~127` — `year` has no plausible-range guard  
**Why**: `year = 20224` (typo) passes validation and silently returns 0 rows. SPI data starts in 2016.  
**Fix**: Add `if (any(year < 2016)) cli::cli_warn(...)` after type validation.

**[F21]** [data] `R/spi-data.R:~204` — no zero-row warning after filtering  
**Why**: All silently-empty results look identical to legitimate empty data, making debugging opaque.  
**Fix**: `if (nrow(dt) == 0L) cli::cli_warn("No rows matched the supplied filters. Verify country/region codes, year range, and {.arg version}.")`

**[F22]** [data] `R/spi-filters.R:~131` — aggregates `pillar` filter silently excludes index-row  
**Why**: The pattern `^SPI\.D{pillar}\.` matches individual indicators but not `SPI.INDEX.PIL{n}` summary rows. `spi_aggregates(pillar = 1)` returns no overall Pillar 1 score, only component indicators.  
**Fix**: Extend pattern or document this limitation explicitly in `@param pillar`.

**[F23]** [data] `vignettes/spi-data-workflows.Rmd:~269` — `reorder(country, SPI.INDEX)` is NA-unsafe  
**Why**: When `SPI.INDEX` has NA values (normal for some country-years), `reorder()` raises a warning and orderings are undefined.  
**Fix**: Add `idx <- idx[!is.na(SPI.INDEX)]` before ggplot call.

### Reproducibility

**[F24]** [repro] `renv.lock`/`pkgdown.yaml` — CRAN mirror mismatch between renv.lock and CI  
**Why**: `renv.lock` records `https://cran.rstudio.com`; CI uses `use-public-rspm: true` (Posit Package Manager). Different checksums for same-version binaries create noisy renv hash validation.  
**Fix**: Align both to PPM: update `renv.lock` Repositories to PPM URL, or remove `use-public-rspm: true` and use CRAN in both environments.

---

## P3 — Nice to Have

**[F25]** [code-quality] `vignettes/spi-data-workflows.Rmd:~393` — `colour = country` confusing as column holds region names in this context  
**Fix**: Rename variable to `region_label` before plotting.

**[F26]** [code-quality] `vignettes/spi-data-workflows.Rmd:~170,~287` — `pillar_labels` defined twice with inconsistent newline usage  
**Fix**: Define `pillar_labels` once at the start of the vignette and reference it in all chunks.

**[F27]** [docs] `_pkgdown.yml:~25` — `navbar: ~` suppresses articles from navbar dropdown  
**Fix**: Remove the `navbar: ~` line to restore the default pkgdown navbar including the "Articles" dropdown.

**[F28]** [docs] `vignettes/spi-data-workflows.Rmd:~25` — only `remotes` install option shown  
**Fix**: Add `pak::pak("WB-DECIS/spiR")` as alternative.

**[F29]** [vc] `NEWS.md:1` — release entry lacks a date  
**Fix**: Change to `# spiR 0.1.0 (2026-04-12)`.

**[F30]** [perf] `vignettes/spi-data-workflows.Rmd` — `melt()` returns factor `variable` column; all 4 uses immediately coerce with `as.character()`  
**Fix**: Add `variable.factor = FALSE` to each `melt()` call.

---

## ✅ Passed

- R CMD check: `Status: OK` (no warnings, no notes)
- No credentials or secrets in any changed file
- `eval = FALSE` globally in vignette — no network calls during check or pkgdown build
- `renv.lock` committed and not gitignored; `renv/` library correctly excluded
- `DESCRIPTION` minimum version bounds declared on all Suggests
- `.cg-docs/` correctly excluded from git (managed block in `.gitignore`)
- `Config/testthat/edition: 3` declared — testthat 3e enabled
- All public functions present in `_pkgdown.yml` reference groups
- No hardcoded absolute file paths in any changed file
