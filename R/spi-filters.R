# Filtering helpers for spi_get() and spi_download().
# None of these functions are exported.

# ---------------------------------------------------------------------------
# Known World Bank aggregate/group ISO3C codes.
# These appear in SPI_databank_country_and_aggregates.csv but do NOT
# represent individual countries. The list is derived from the WB country
# classification and changes rarely.
# ---------------------------------------------------------------------------
SPI_AGGREGATE_CODES <- c(
  "AFE", "AFW", "ARB", "CEB", "CSS",
  "EAP", "EAR", "EAS", "ECA", "ECS", "EMU", "EUU",
  "FCS",
  "HIC", "HPC",
  "IBD", "IBT", "IDA", "IDB", "IDX",
  "LAC", "LCN", "LDC", "LIC", "LMC", "LMY", "LTE",
  "MEA", "MIC", "MNA",
  "NAC",
  "OED", "OSS",
  "PRE", "PSS", "PST",
  "SAS", "SSA", "SSF", "SST",
  "TEA", "TEC", "TLA", "TMN", "TSA", "TSS",
  "UMC",
  "WLD"
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

#' Check whether an ISO3C code is a WB aggregate/group code
#'
#' @param code Character vector of ISO3C codes.
#' @return Logical vector, TRUE where the code is a known WB aggregate.
#' @keywords internal
is_aggregate_code <- function(code) {
  code %in% SPI_AGGREGATE_CODES
}

#' Identify identifier/metadata columns in a wide SPI data.table
#'
#' Columns that do NOT start with `SPI.D<digit>` or `RAW.D<digit>` are
#' treated as identifiers (e.g. `iso3c`, `date`, `country`, `SPI.INDEX`,
#' `SPI.DIM*`). These are always preserved during column filtering.
#'
#' @param dt A `data.table`.
#' @return Character vector of column names.
#' @keywords internal
identify_id_columns <- function(dt) {
  cols <- names(dt)
  # Keep columns that are NOT SPI indicator columns (SPI.D<n>) or RAW
  # indicator columns (RAW.D<n>). Aggregate index columns like SPI.INDEX,
  # SPI.INDEX.PIL1, SPI.DIM*, etc. don't match this pattern and are kept.
  cols[!grepl("^SPI\\.D[0-9]|^RAW\\.D[0-9]", cols)]
}

#' Filter wide SPI data.table columns by regex pattern (internal helper)
#'
#' Keeps identifier columns plus all indicator columns whose names match
#' `pattern`. Shared implementation for [filter_columns_by_pillar()] and
#' [filter_columns_by_dimension()].
#'
#' @param dt A `data.table` (wide format).
#' @param pattern Character scalar. A regex to match against column names.
#' @return A `data.table` with only the relevant columns.
#' @keywords internal
filter_columns_by_pattern <- function(dt, pattern) {
  id_cols       <- identify_id_columns(dt)
  indicator_cols <- names(dt)[grepl(pattern, names(dt))]
  dt[, union(id_cols, indicator_cols), with = FALSE]
}

#' Filter wide SPI data.table columns by pillar
#'
#' Keeps identifier columns plus all indicator columns belonging to the
#' specified pillar (`SPI.D{pillar}.*` and `RAW.D{pillar}.*`).
#'
#' @param dt A `data.table` (wide format, e.g. from SPI_data.csv or
#'   SPI_index.csv).
#' @param pillar Integer 1–5, or `NULL` (no filtering).
#' @return A `data.table` with only the relevant columns.
#' @keywords internal
filter_columns_by_pillar <- function(dt, pillar) {
  if (is.null(pillar)) return(dt)
  pattern <- paste0("^SPI\\.D", pillar, "\\.|^RAW\\.D", pillar, "\\.")
  filter_columns_by_pattern(dt, pattern)
}

#' Filter wide SPI data.table columns by dimension
#'
#' Keeps identifier columns plus all indicator columns belonging to the
#' specified dimension (e.g. `"5.2"` matches `SPI.D5.2.*` and
#' `RAW.D5.2.*`).
#'
#' @param dt A `data.table` (wide format).
#' @param dimension Character string in `"P.D"` format (e.g. `"5.2"`),
#'   or `NULL` (no filtering).
#' @return A `data.table` with only the relevant columns.
#' @keywords internal
filter_columns_by_dimension <- function(dt, dimension) {
  if (is.null(dimension)) return(dt)
  dim_escaped <- gsub("\\.", "\\\\.", dimension)
  pattern <- paste0("^SPI\\.D", dim_escaped, "\\.|^RAW\\.D", dim_escaped, "\\.")
  filter_columns_by_pattern(dt, pattern)
}

#' Filter long aggregates data.table rows by pillar and/or dimension
#'
#' Filters the `source_id` column in the aggregates long-format data.table.
#' When both `pillar` and `dimension` are provided, `dimension` (more
#' specific) takes precedence.
#'
#' @param dt A `data.table` (long format, from
#'   `SPI_databank_country_and_aggregates.csv`).
#' @param pillar Integer 1–5, or `NULL`.
#' @param dimension Character string in `"P.D"` format, or `NULL`.
#' @return A filtered `data.table`.
#' @keywords internal
filter_rows_by_pillar_dimension <- function(dt, pillar, dimension) {
  if (!is.null(dimension)) {
    # dimension is more specific — use it and ignore pillar
    dim_escaped <- gsub("\\.", "\\\\.", dimension)
    pattern <- paste0("^SPI\\.D", dim_escaped, "\\.")
    keep <- grepl(pattern, dt[["source_id"]])
    return(dt[keep])
  }

  if (!is.null(pillar)) {
    pattern <- paste0("^SPI\\.D", pillar, "\\.")
    keep <- grepl(pattern, dt[["source_id"]])
    return(dt[keep])
  }

  dt
}
# ---------------------------------------------------------------------------
# Inventory path enrichment (used by spi-inventory-cache.R)
# ---------------------------------------------------------------------------

#' Enrich a raw file-tree data.table with pillar, dimension, and category
#'
#' Takes a raw `data.table` (from the GitHub tree crawler) with at minimum a
#' `path` column and adds three metadata columns derived from each file path:
#'
#' - `category`: `"raw"` for files under `01_raw_data/`, `"output"` for
#'   files under `03_output_data/`, and `"misc"` for everything else.
#' - `pillar`: integer 1\u20135 extracted from the first subfolder name under
#'   `01_raw_data/` (e.g. `4.1_SOCS` \u2192 `4L`). `NA` for all other paths.
#' - `dimension`: character in `"P.D"` format from the same subfolder
#'   (e.g. `4.1_SOCS` \u2192 `"4.1"`). `NA` when the subfolder encodes only a
#'   pillar (e.g. `3_DP`) or the path falls outside `01_raw_data/`.
#'
#' The function is pure: it copies the input before enriching, so the
#' original `data.table` is never modified.
#'
#' @param tree_dt A `data.table` with at minimum a character `path` column.
#' @return A `data.table` with six columns: `path`, `type`, `size`,
#'   `category`, `pillar`, `dimension`.
#' @keywords internal
.spi_enrich_tree <- function(tree_dt) {
  if (!data.table::is.data.table(tree_dt))
    cli::cli_abort("{.arg tree_dt} must be a {.cls data.table}, not {.cls {class(tree_dt)[1L]}}.")
  if (!"path" %in% names(tree_dt))
    cli::cli_abort("{.arg tree_dt} must contain a {.field path} column.")
  if (!is.character(tree_dt[["path"]]))
    cli::cli_abort("Column {.field path} must be character, not {.cls {class(tree_dt$path)[1L]}}.")

  dt   <- data.table::copy(tree_dt)
  path <- dt[["path"]]

  na_paths <- sum(is.na(path))
  if (na_paths > 0L)
    cli::cli_warn("{na_paths} NA value{?s} in {.field path} treated as {.val misc}.")

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
    # Strip the "01_raw_data/" prefix, then take text before the next "/".
    after_prefix    <- substring(path[raw_idx], nchar("01_raw_data/") + 1L)
    subdir[raw_idx] <- sub("/.*$", "", after_prefix)
  }

  # Compute pil_hits first; dim_hits is a strict subset (P.D folders also
  # satisfy the leading-digit pattern), avoiding a redundant grep pass.
  pil_hits <- grep("^[0-9]+", subdir)
  dim_hits <- pil_hits[grepl("^[0-9]+\\.[0-9]+", subdir[pil_hits])]

  dim_vec <- rep(NA_character_, length(path))
  if (length(dim_hits) > 0L) {
    dim_vec[dim_hits] <- regmatches(
      subdir[dim_hits],
      regexpr("^[0-9]+\\.[0-9]+", subdir[dim_hits])
    )
  }

  pil_vec <- rep(NA_integer_, length(path))
  if (length(pil_hits) > 0L) {
    pil_vec[pil_hits] <- as.integer(regmatches(
      subdir[pil_hits],
      regexpr("^[0-9]+", subdir[pil_hits])
    ))
  }

  dt[, c("pillar", "dimension") := list(pil_vec, dim_vec)]

  return(dt)
}