---
date: 2026-04-12
title: "pkgdown GitHub Actions deploy fires on PRs without an if: guard, causing permissions errors and dirty gh-pages history"
category: "git-workflows"
language: "R"
tags: [pkgdown, github-actions, gh-pages, JamesIves, permissions, CI]
root-cause: "Deploy step has no if: condition, so it runs on every pull_request trigger"
severity: "P1"
---

# pkgdown GHA deploy-on-PR bug

## Problem

A pkgdown GitHub Actions workflow with the following structure:

```yaml
on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]
  release:
    types: [published]

permissions:
  contents: write
  pages: write
  id-token: write

jobs:
  pkgdown:
    steps:
      - name: Deploy to GitHub Pages
        uses: JamesIves/github-pages-deploy-action@v4
        with:
          branch: gh-pages
          folder: docs
```

causes two failure modes:

1. **Fork PRs** → the ephemeral `GITHUB_TOKEN` for a fork has no write access
   to the target repo's `gh-pages` branch. The deploy step fails with a
   permissions error, generating red CI that misleads reviewers into thinking
   the site *build* is broken (it isn't — only the deploy failed).

2. **Same-repo PRs** → the deploy step succeeds, pushing unreviewed/draft
   branch content directly to `gh-pages`. This silently overwrites the deployed
   site and pollutes the `gh-pages` commit history.

Additionally, `pages: write` and `id-token: write` are only needed for the
`actions/upload-pages-artifact` + `actions/deploy-pages` approach (the
GitHub Pages environment API). The JamesIves direct-branch-push approach
requires **only** `contents: write`. The two extra scopes over-provision the
`GITHUB_TOKEN`.

## Root Cause

The `JamesIves/github-pages-deploy-action` step has no `if:` condition, so it
runs unconditionally on every trigger including `pull_request`. The
`pages: write` and `id-token: write` scopes were copied from a different
GitHub Pages deployment pattern that uses the Pages environment API instead.

## Solution

**1. Guard the deploy step** so it only runs on pushes and releases, not PRs:

```yaml
      - name: Deploy to GitHub Pages
        if: github.event_name != 'pull_request'
        uses: JamesIves/github-pages-deploy-action@v4
        with:
          branch: gh-pages
          folder: docs
          clean: true
```

**2. Trim permissions** to only what the JamesIves action actually needs:

```yaml
permissions:
  contents: write
```

**3. Pin the runner** to a specific Ubuntu version to avoid silent OS upgrades
(which can change native library versions for packages like `httr2`, `curl`,
`openssl`):

```yaml
runs-on: ubuntu-22.04
```

**4. Pin the R version** to match `renv.lock`:

```yaml
      - uses: r-lib/actions/setup-r@v2
        with:
          r-version: "4.3.1"
```

### Complete minimal-safe workflow skeleton

```yaml
on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]
  release:
    types: [published]
  workflow_dispatch:

name: pkgdown

permissions:
  contents: write

jobs:
  pkgdown:
    runs-on: ubuntu-22.04
    env:
      GITHUB_PAT: ${{ secrets.GITHUB_TOKEN }}
    steps:
      - uses: actions/checkout@v4
      - uses: r-lib/actions/setup-pandoc@v2
      - uses: r-lib/actions/setup-r@v2
        with:
          r-version: "4.3.1"
      - uses: r-lib/actions/setup-r-dependencies@v2
        with:
          extra-packages: any::pkgdown, local::.
          needs: website
      - name: Build pkgdown site
        run: pkgdown::build_site_github_pages(new_process = FALSE, install = FALSE)
        shell: Rscript {0}
      - name: Deploy to GitHub Pages
        if: github.event_name != 'pull_request'
        uses: JamesIves/github-pages-deploy-action@v4
        with:
          branch: gh-pages
          folder: docs
          clean: true
```

## Prevention

- Always add `if: github.event_name != 'pull_request'` to any deploy step in
  a workflow that also triggers on `pull_request`.
- Match the permissions scope to the deploy action being used:
  - JamesIves `github-pages-deploy-action` → `contents: write` only
  - GitHub native Pages API (`upload-pages-artifact` + `deploy-pages`) → `pages: write` + `id-token: write`
- Pin `runs-on` and `r-version` in every R package CI workflow.
- The `pull_request:` trigger on the pkgdown workflow is still useful: it runs
  the build step to catch vignette/reference errors on PRs. Only the deploy
  step should be skipped.

## Related

- [JamesIves action docs](https://github.com/JamesIves/github-pages-deploy-action)
- [r-lib/actions pkgdown standard workflow](https://github.com/r-lib/actions/blob/v2-branch/examples/pkgdown.yaml)
