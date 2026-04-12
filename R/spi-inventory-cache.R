# Inventory cache system for the spiR package.
#
# Stores crawled GitHub file trees on disk (one RDS per version/branch)
# to avoid redundant GitHub API calls on every spi_inventory() call.
#
# Public API  : spi_update_inventory(), spi_clear_inventory()
# Internal    : .spi_enrich_tree(), .spi_cache_dir(), .spi_cache_path(),
#               .spi_write_cache(), .spi_read_cache(), .spi_get_inventory()
# Stub (TBR)  : .spi_crawl_tree() — replaced by the github-tree-crawler feature

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

INVENTORY_CACHE_SCHEMA_VERSION <- 1L
INVENTORY_CACHE_TTL_DAYS       <- 30L

# ---------------------------------------------------------------------------
# Stub: tree crawler (will be replaced by github-tree-crawler feature)
# ---------------------------------------------------------------------------

#' Internal stub: crawl the SPI GitHub repository file tree
#'
#' Placeholder for the `github-tree-crawler` feature. When that feature is
#' implemented this function will be replaced by one that calls the GitHub
#' Trees API and returns the full recursive file tree as a `data.table`.
#'
#' @param version Character. Branch name.
#' @return A `data.table` with columns `path`, `type`, `size`.
#' @keywords internal
.spi_crawl_tree <- function(version = "master") {
  cli::cli_abort(c(
    "The GitHub tree crawler is not yet implemented.",
    "i" = "This feature is planned for the {.code github-tree-crawler} milestone."
  ))
}

# ---------------------------------------------------------------------------
# Step 1: Path-enrichment logic (R4, R11-R14)
# ---------------------------------------------------------------------------

#' Enrich a raw file-tree data.table with pillar, dimension, and category
#'
#' Takes a raw `data.table` (from the GitHub tree crawler) with at minimum a
#' `path` column and adds three metadata columns derived from each file path:
#'
#' - `category`: `"raw"` for files under `01_raw_data/`, `"output"` for
#'   files under `03_output_data/`, and `"misc"` for everything else.
#' - `pillar`: integer 1–5 extracted from the first subfolder name under
#'   `01_raw_data/` (e.g. `4.1_SOCS` → `4L`). `NA` for all other paths.
#' - `dimension`: character in `"P.D"` format from the same subfolder
#'   (e.g. `4.1_SOCS` → `"4.1"`). `NA` when the subfolder encodes only a
#'   pillar (e.g. `3_DP`) or the path falls outside `01_raw_data/`.
#'
#' The function is pure: it copies the input and adds columns without
#' modifying the original `data.table`.
#'
#' @param tree_dt A `data.table` with at minimum a character `path` column.
#' @return A `data.table` with six columns: `path`, `type`, `size`,
#'   `category`, `pillar`, `dimension`.
#' @keywords internal
.spi_enrich_tree <- function(tree_dt) {
  dt   <- data.table::copy(tree_dt)
  path <- dt[["path"]]

  # --- category ------------------------------------------------------------
  # Derive from the top-level folder prefix.
  category <- rep("misc", length(path))
  category[startsWith(path, "01_raw_data/")]    <- "raw"
  category[startsWith(path, "03_output_data/")] <- "output"
  dt[, category := category]

  # --- pillar and dimension (raw paths only) -------------------------------
  # Extract the first subfolder immediately under 01_raw_data/, e.g.:
  #   "01_raw_data/4.1_SOCS/file.csv"         -> subdir = "4.1_SOCS"
  #   "01_raw_data/3_DP/2024/score.csv"        -> subdir = "3_DP"
  #   "01_raw_data/metadata/codes.csv"         -> subdir = "metadata"
  raw_idx <- which(category == "raw")
  subdir  <- rep(NA_character_, length(path))

  if (length(raw_idx) > 0L) {
    # Strip the "01_raw_data/" prefix (12 characters), then take text before
    # the next "/" to isolate the immediate subfolder name.
    after_prefix    <- substring(path[raw_idx], nchar("01_raw_data/") + 1L)
    subdir[raw_idx] <- sub("/.*$", "", after_prefix)
  }

  # dimension: match "P.D" (digits.digits) at the start of the subfolder
  dim_vec  <- rep(NA_character_, length(path))
  dim_hits <- grep("^[0-9]+\\.[0-9]+", subdir)
  if (length(dim_hits) > 0L) {
    dim_vec[dim_hits] <- regmatches(
      subdir[dim_hits],
      regexpr("^[0-9]+\\.[0-9]+", subdir[dim_hits])
    )
  }

  # pillar: leading integer from the subfolder name (works for both "P.D_"
  # and "P_" style folder names)
  pil_vec  <- rep(NA_integer_, length(path))
  pil_hits <- grep("^[0-9]+", subdir)
  if (length(pil_hits) > 0L) {
    pil_vec[pil_hits] <- as.integer(regmatches(
      subdir[pil_hits],
      regexpr("^[0-9]+", subdir[pil_hits])
    ))
  }

  dt[, pillar    := pil_vec]
  dt[, dimension := dim_vec]

  return(dt)
}

# ---------------------------------------------------------------------------
# Step 2: Cache directory helpers (R1, R2)
# ---------------------------------------------------------------------------

#' Resolve (and create if necessary) the spiR inventory cache directory
#'
#' @importFrom tools R_user_dir
#' @return Character scalar: absolute path to the cache directory.
#' @keywords internal
.spi_cache_dir <- function() {
  dir <- tools::R_user_dir("spiR", "cache")
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
  return(dir)
}

#' Build the absolute path to a version's inventory cache file
#'
#' @param version Character. Branch name (e.g. `"master"`, `"SPI2023"`).
#' @return Character scalar: path to `tree_{version}.rds` inside the cache
#'   directory.
#' @keywords internal
.spi_cache_path <- function(version) {
  file.path(.spi_cache_dir(), paste0("tree_", version, ".rds"))
}

# ---------------------------------------------------------------------------
# Step 2: Cache read / write (R3, R5, R9, R10)
# ---------------------------------------------------------------------------

#' Write an enriched inventory tree to the on-disk cache
#'
#' Enriches `tree_dt` (via [.spi_enrich_tree()]), then saves a named list
#' with `schema_version`, `timestamp`, and `tree` as an RDS file keyed by
#' the branch name.
#'
#' @param tree_dt A raw `data.table` from the GitHub tree crawler.
#' @param version Character. Branch name (determines the cache file name).
#' @return The enriched `data.table`, invisibly.
#' @keywords internal
.spi_write_cache <- function(tree_dt, version) {
  enriched  <- .spi_enrich_tree(tree_dt)
  cache_obj <- list(
    schema_version = INVENTORY_CACHE_SCHEMA_VERSION,
    timestamp      = Sys.time(),
    tree           = enriched
  )
  saveRDS(cache_obj, file = .spi_cache_path(version))
  invisible(enriched)
}

#' Read and validate the on-disk inventory cache for a version
#'
#' Returns `NULL` (so the caller knows to re-crawl) in four situations:
#' \itemize{
#'   \item File does not exist.
#'   \item File is older than 30 days (silent expiry).
#'   \item File cannot be read (corrupt). A warning is emitted and the file
#'     is deleted.
#'   \item File has an incompatible `schema_version`. A warning is emitted
#'     and the file is deleted.
#' }
#'
#' @param version Character. Branch name.
#' @return A `data.table` (the cached tree), or `NULL`.
#' @keywords internal
.spi_read_cache <- function(version) {
  path <- .spi_cache_path(version)

  if (!file.exists(path)) return(NULL)

  # --- Attempt to deserialise --------------------------------------------
  cache_obj <- tryCatch(
    readRDS(path),
    error = function(e) {
      cli::cli_warn(c(
        "Cached inventory for version {.val {version}} is corrupted and will be deleted.",
        "i" = "It will be re-fetched on the next call.",
        "x" = "Caused by: {conditionMessage(e)}"
      ))
      unlink(path)
      NULL
    }
  )
  if (is.null(cache_obj)) return(NULL)

  # --- Validate structure -------------------------------------------------
  expected_names <- c("schema_version", "timestamp", "tree")
  if (!is.list(cache_obj) || !all(expected_names %in% names(cache_obj))) {
    cli::cli_warn(c(
      "Cached inventory for version {.val {version}} has an unexpected structure and will be deleted.",
      "i" = "It will be re-fetched on the next call."
    ))
    unlink(path)
    return(NULL)
  }

  # --- Check schema version -----------------------------------------------
  if (!identical(cache_obj[["schema_version"]], INVENTORY_CACHE_SCHEMA_VERSION)) {
    cli::cli_warn(c(
      "Cached inventory for version {.val {version}} uses an incompatible schema (v{cache_obj$schema_version}) and will be deleted.",
      "i" = "Expected schema v{INVENTORY_CACHE_SCHEMA_VERSION}. It will be re-fetched on the next call."
    ))
    unlink(path)
    return(NULL)
  }

  # --- Check TTL ----------------------------------------------------------
  age_days <- as.numeric(
    difftime(Sys.time(), cache_obj[["timestamp"]], units = "days")
  )
  if (age_days > INVENTORY_CACHE_TTL_DAYS) {
    return(NULL)  # Silent expiry — caller will re-crawl
  }

  return(cache_obj[["tree"]])
}

# ---------------------------------------------------------------------------
# Step 3: Inventory resolver (R5, R8)
# ---------------------------------------------------------------------------

#' Internal: resolve the inventory tree for a given SPI version
#'
#' Returns the on-disk cached tree when valid and fresh. Falls back to
#' crawling the GitHub repository when the cache is absent, expired, or
#' corrupt. Errors clearly when neither cache nor network is available.
#'
#' This is the single entry point for all inventory consumers (e.g.
#' `spi_inventory()`, `spi_get_raw()` — planned features).
#'
#' @param version Character. Branch name. Default `"master"`.
#' @return A `data.table` with columns `path`, `type`, `size`, `category`,
#'   `pillar`, `dimension`.
#' @keywords internal
.spi_get_inventory <- function(version = "master") {
  cached <- .spi_read_cache(version)
  if (!is.null(cached)) return(cached)

  # Cache miss / expired — try to crawl the repository
  tree_dt <- tryCatch(
    .spi_crawl_tree(version),
    error = function(e) {
      cli::cli_abort(c(
        "No cached inventory found and the GitHub API could not be reached.",
        "x" = "Caused by: {conditionMessage(e)}",
        "i" = "Connect to the internet and try again, or call {.fn spi_update_inventory}."
      ))
    }
  )

  .spi_write_cache(tree_dt, version)
}

# ---------------------------------------------------------------------------
# Step 4: Exported functions
# ---------------------------------------------------------------------------

#' Update the local SPI inventory cache
#'
#' Forces a fresh crawl of the
#' [World Bank SPI repository](https://github.com/worldbank/SPI) for the
#' specified version and writes the result to the on-disk inventory cache.
#' Useful when the remote repository has been updated and you want to
#' refresh before the automatic 30-day TTL expires.
#'
#' @param version Character. Branch name in the SPI repository. Defaults to
#'   `"master"` (latest stable). Use [spi_versions()] to list all available
#'   branches.
#'
#' @return The updated inventory `data.table`, invisibly. Each row
#'   represents one file in the SPI repository, with columns:
#'   \describe{
#'     \item{`path`}{Relative file path within the repository.}
#'     \item{`type`}{GitHub object type: `"blob"` (file) or `"tree"`
#'       (directory).}
#'     \item{`size`}{File size in bytes (`NA` for directories).}
#'     \item{`category`}{`"raw"`, `"output"`, or `"misc"`.}
#'     \item{`pillar`}{Integer 1–5, or `NA`.}
#'     \item{`dimension`}{Character `"P.D"` (e.g. `"4.1"`), or `NA`.}
#'   }
#'
#' @seealso [spi_clear_inventory()], [spi_versions()]
#'
#' @examples
#' \dontrun{
#' # Refresh the default version
#' spi_update_inventory()
#'
#' # Refresh a specific version
#' spi_update_inventory(version = "SPI2023")
#' }
#'
#' @importFrom cli cli_inform
#' @export
spi_update_inventory <- function(version = "master") {
  if (!is.character(version) || length(version) != 1L || !nzchar(version)) {
    cli::cli_abort(c(
      "{.arg version} must be a single non-empty character string.",
      "x" = "You supplied a {.cls {class(version)[1L]}}."
    ))
  }

  tree_dt <- .spi_crawl_tree(version)
  result  <- .spi_write_cache(tree_dt, version)
  cli::cli_inform("Inventory updated for version {.val {version}}.")
  invisible(result)
}

#' Clear the local SPI inventory cache
#'
#' Deletes on-disk inventory cache files written by [spi_update_inventory()]
#' or automatically by inventory functions. Does **not** affect the
#' in-session download cache — use [spi_clear_cache()] for that.
#'
#' @param version Character or `NULL`. A branch name deletes only that
#'   version's cache file. `NULL` (default) deletes all cached inventory
#'   files.
#'
#' @return `NULL`, invisibly.
#'
#' @seealso [spi_update_inventory()], [spi_clear_cache()]
#'
#' @examples
#' \dontrun{
#' # Delete the cache for one version
#' spi_clear_inventory("master")
#'
#' # Delete all inventory cache files
#' spi_clear_inventory()
#' }
#'
#' @export
spi_clear_inventory <- function(version = NULL) {
  if (!is.null(version)) {
    if (!is.character(version) || length(version) != 1L || !nzchar(version)) {
      cli::cli_abort(c(
        "{.arg version} must be a single non-empty character string or {.code NULL}.",
        "x" = "You supplied a {.cls {class(version)[1L]}} of length {length(version)}."
      ))
    }
    path <- .spi_cache_path(version)
    if (file.exists(path)) {
      unlink(path)
      cli::cli_inform("Inventory cache cleared for version {.val {version}}.")
    } else {
      cli::cli_inform("No inventory cache found for version {.val {version}}.")
    }
  } else {
    cache_dir <- .spi_cache_dir()
    files     <- list.files(cache_dir, pattern = "^tree_.*\\.rds$", full.names = TRUE)
    if (length(files) == 0L) {
      cli::cli_inform("Inventory cache is already empty.")
    } else {
      unlink(files)
      cli::cli_inform("Inventory cache cleared ({length(files)} file{?s} deleted).")
    }
  }

  invisible(NULL)
}
