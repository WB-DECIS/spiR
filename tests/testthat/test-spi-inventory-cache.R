# Tests for the inventory cache system.
#
# All tests are unit tests — no network calls. The GitHub tree crawler
# (.spi_crawl_tree) is mocked via local_mocked_bindings(). The cache
# directory is redirected to a per-test temp dir so the real user cache
# is never touched.

library(data.table)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Redirect the cache directory to a temporary directory for a test.
# The temp dir is cleaned up and the mock is reverted when the test ends.
local_inventory_cache <- function(env = parent.frame()) {
  tmp <- withr::local_tempdir(.local_envir = env)
  local_mocked_bindings(.spi_cache_dir = function() tmp, .env = env)
  invisible(tmp)
}

# Minimal representative file tree covering raw/output/misc + all enrichment
# scenarios (P.D_ folders, P_ folders, non-pillar raw subfolders).
make_raw_tree <- function() {
  data.table(
    path = c(
      "01_raw_data/4.1_SOCS/file.csv",           # raw, pillar 4, dim 4.1
      "01_raw_data/5.2_Infrastructure/data.csv",  # raw, pillar 5, dim 5.2
      "01_raw_data/3_DP/2024/score.csv",          # raw, pillar 3, dim NA
      "01_raw_data/metadata/country_codes.csv",   # raw, pillar NA, dim NA
      "03_output_data/SPI_data.csv",              # output, pillar NA, dim NA
      "03_output_data/SPI_index.csv",             # output, pillar NA, dim NA
      "README.md"                                 # misc
    ),
    type = rep("blob", 7L),
    size = c(1024L, 2048L, 512L, 256L, 9999L, 8888L, 1024L)
  )
}

mock_crawl_success <- function(version) make_raw_tree()
mock_crawl_fail    <- function(version) {
  cli::cli_abort("Connection timed out")
}

# ---------------------------------------------------------------------------
# 1. Path-enrichment logic
# ---------------------------------------------------------------------------

describe(".spi_enrich_tree()", {
  it("returns a data.table with exactly 6 columns", {
    result <- .spi_enrich_tree(make_raw_tree())
    expect_s3_class(result, "data.table")
    expect_equal(ncol(result), 6L)
    expect_true(all(
      c("path", "type", "size", "category", "pillar", "dimension") %in%
        names(result)
    ))
  })

  it("assigns 'raw' category to 01_raw_data/ paths", {
    result <- .spi_enrich_tree(make_raw_tree())
    raw_paths <- result[startsWith(path, "01_raw_data/"), category]
    expect_true(all(raw_paths == "raw"))
  })

  it("assigns 'output' category to 03_output_data/ paths", {
    result <- .spi_enrich_tree(make_raw_tree())
    out_paths <- result[startsWith(path, "03_output_data/"), category]
    expect_true(all(out_paths == "output"))
  })

  it("assigns 'misc' category to root-level and other paths", {
    result <- .spi_enrich_tree(make_raw_tree())
    expect_equal(result[path == "README.md", category], "misc")
  })

  it("parses pillar and dimension from P.D_ subfolder names", {
    result <- .spi_enrich_tree(make_raw_tree())
    expect_equal(result[path == "01_raw_data/4.1_SOCS/file.csv",          pillar], 4L)
    expect_equal(result[path == "01_raw_data/4.1_SOCS/file.csv",          dimension], "4.1")
    expect_equal(result[path == "01_raw_data/5.2_Infrastructure/data.csv", pillar], 5L)
    expect_equal(result[path == "01_raw_data/5.2_Infrastructure/data.csv", dimension], "5.2")
  })

  it("parses pillar but leaves dimension NA for P_ subfolder names", {
    result <- .spi_enrich_tree(make_raw_tree())
    expect_equal(result[path == "01_raw_data/3_DP/2024/score.csv", pillar], 3L)
    expect_true(is.na(result[path == "01_raw_data/3_DP/2024/score.csv", dimension]))
  })

  it("returns NA pillar and dimension for non-pillar raw subfolders", {
    result <- .spi_enrich_tree(make_raw_tree())
    expect_true(is.na(result[path == "01_raw_data/metadata/country_codes.csv", pillar]))
    expect_true(is.na(result[path == "01_raw_data/metadata/country_codes.csv", dimension]))
  })

  it("returns NA pillar and dimension for output and misc paths", {
    result <- .spi_enrich_tree(make_raw_tree())
    expect_true(is.na(result[path == "03_output_data/SPI_data.csv", pillar]))
    expect_true(is.na(result[path == "03_output_data/SPI_data.csv", dimension]))
    expect_true(is.na(result[path == "README.md", pillar]))
    expect_true(is.na(result[path == "README.md", dimension]))
  })

  it("does not modify the original data.table (copy semantics)", {
    raw <- make_raw_tree()
    before_cols <- names(raw)
    .spi_enrich_tree(raw)
    expect_equal(names(raw), before_cols)
    expect_equal(ncol(raw), 3L)
  })

  it("handles unexpected subfolder names without error", {
    weird <- data.table(
      path = "01_raw_data/unknown_folder/file.csv",
      type = "blob",
      size = 100L
    )
    expect_no_error(.spi_enrich_tree(weird))
    result <- .spi_enrich_tree(weird)
    expect_true(is.na(result[["pillar"]]))
    expect_true(is.na(result[["dimension"]]))
  })
})

# ---------------------------------------------------------------------------
# 2. Cache read / write infrastructure
# ---------------------------------------------------------------------------

describe("cache read/write", {
  it("round-trip: write then read returns same row count", {
    local_inventory_cache()
    .spi_write_cache(make_raw_tree(), "master")
    result <- .spi_read_cache("master")
    expect_s3_class(result, "data.table")
    expect_equal(nrow(result), nrow(make_raw_tree()))
  })

  it("round-trip result has all 6 expected columns", {
    local_inventory_cache()
    .spi_write_cache(make_raw_tree(), "master")
    result <- .spi_read_cache("master")
    expect_true(all(
      c("path", "type", "size", "category", "pillar", "dimension") %in%
        names(result)
    ))
  })

  it("returns NULL for a non-existent cache file (no warning)", {
    local_inventory_cache()
    expect_no_warning(result <- .spi_read_cache("nonexistent-branch"))
    expect_null(result)
  })

  it("returns NULL silently for an expired cache (>30 days)", {
    local_inventory_cache()
    old_cache <- list(
      schema_version = INVENTORY_CACHE_SCHEMA_VERSION,
      timestamp      = Sys.time() - (31L * 86400L),
      tree           = .spi_enrich_tree(make_raw_tree())
    )
    saveRDS(old_cache, file = .spi_cache_path("master"))
    expect_no_warning(result <- .spi_read_cache("master"))
    expect_null(result)
  })

  it("warns and returns NULL for a corrupted cache file", {
    local_inventory_cache()
    writeLines("THIS IS NOT VALID RDS", .spi_cache_path("master"))
    expect_warning(
      result <- .spi_read_cache("master"),
      "corrupted"
    )
    expect_null(result)
  })

  it("deletes the corrupted file after warning", {
    local_inventory_cache()
    path <- .spi_cache_path("master")
    writeLines("THIS IS NOT VALID RDS", path)
    suppressWarnings(.spi_read_cache("master"))
    expect_false(file.exists(path))
  })

  it("warns and returns NULL for an incompatible schema version", {
    local_inventory_cache()
    bad_cache <- list(
      schema_version = 99L,
      timestamp      = Sys.time(),
      tree           = .spi_enrich_tree(make_raw_tree())
    )
    saveRDS(bad_cache, file = .spi_cache_path("master"))
    expect_warning(
      result <- .spi_read_cache("master"),
      "incompatible schema"
    )
    expect_null(result)
  })

  it("deletes the incompatible-schema file after warning", {
    local_inventory_cache()
    path <- .spi_cache_path("master")
    bad_cache <- list(
      schema_version = 99L,
      timestamp      = Sys.time(),
      tree           = .spi_enrich_tree(make_raw_tree())
    )
    saveRDS(bad_cache, path)
    suppressWarnings(.spi_read_cache("master"))
    expect_false(file.exists(path))
  })

  it("warns and returns NULL for a cache with missing required fields", {
    local_inventory_cache()
    bad_cache <- list(schema_version = INVENTORY_CACHE_SCHEMA_VERSION)
    saveRDS(bad_cache, file = .spi_cache_path("master"))
    expect_warning(
      result <- .spi_read_cache("master"),
      "unexpected structure"
    )
    expect_null(result)
  })

  it("caches different versions independently", {
    local_inventory_cache()
    .spi_write_cache(make_raw_tree(), "master")
    expect_null(.spi_read_cache("SPI2023"))
    expect_s3_class(.spi_read_cache("master"), "data.table")
  })
})

# ---------------------------------------------------------------------------
# 3. Inventory resolver (.spi_get_inventory)
# ---------------------------------------------------------------------------

describe(".spi_get_inventory()", {
  it("returns the cached tree on a cache hit without calling the crawler", {
    local_inventory_cache()
    .spi_write_cache(make_raw_tree(), "master")
    # The fail mock should never be called if the cache is valid
    local_mocked_bindings(.spi_crawl_tree = mock_crawl_fail)
    expect_s3_class(.spi_get_inventory("master"), "data.table")
  })

  it("calls the crawler and writes cache on a cache miss", {
    local_inventory_cache()
    crawled <- FALSE
    local_mocked_bindings(
      .spi_crawl_tree = function(v) { crawled <<- TRUE; make_raw_tree() }
    )
    result <- .spi_get_inventory("master")
    expect_true(crawled)
    expect_s3_class(result, "data.table")
    expect_true(file.exists(.spi_cache_path("master")))
  })

  it("re-crawls and overwrites an expired cache", {
    local_inventory_cache()
    old_cache <- list(
      schema_version = INVENTORY_CACHE_SCHEMA_VERSION,
      timestamp      = Sys.time() - (31L * 86400L),
      tree           = .spi_enrich_tree(make_raw_tree())
    )
    saveRDS(old_cache, file = .spi_cache_path("master"))
    crawled <- FALSE
    local_mocked_bindings(
      .spi_crawl_tree = function(v) { crawled <<- TRUE; make_raw_tree() }
    )
    .spi_get_inventory("master")
    expect_true(crawled)
  })

  it("errors clearly when no cache and no network", {
    local_inventory_cache()
    local_mocked_bindings(.spi_crawl_tree = mock_crawl_fail)
    expect_error(
      .spi_get_inventory("master"),
      "No cached inventory found"
    )
  })
})

# ---------------------------------------------------------------------------
# 4. Exported functions
# ---------------------------------------------------------------------------

describe("spi_update_inventory()", {
  it("calls the crawler, writes the cache, and returns the tree invisibly", {
    local_inventory_cache()
    local_mocked_bindings(.spi_crawl_tree = mock_crawl_success)
    result <- spi_update_inventory("master")
    expect_s3_class(result, "data.table")
    expect_true(file.exists(.spi_cache_path("master")))
  })

  it("informs the user after a successful update", {
    local_inventory_cache()
    local_mocked_bindings(.spi_crawl_tree = mock_crawl_success)
    expect_message(spi_update_inventory("master"), "Inventory updated")
  })

  it("rejects a non-character version", {
    expect_error(spi_update_inventory(version = 123), "`version`")
  })

  it("rejects a vector version", {
    expect_error(spi_update_inventory(version = c("a", "b")), "`version`")
  })

  it("rejects an empty-string version", {
    expect_error(spi_update_inventory(version = ""), "`version`")
  })
})

describe("spi_clear_inventory()", {
  it("deletes the cache file for a specific version", {
    local_inventory_cache()
    local_mocked_bindings(.spi_crawl_tree = mock_crawl_success)
    spi_update_inventory("master")
    path <- .spi_cache_path("master")
    expect_true(file.exists(path))
    spi_clear_inventory("master")
    expect_false(file.exists(path))
  })

  it("deletes all tree_*.rds files when version is NULL", {
    local_inventory_cache()
    local_mocked_bindings(.spi_crawl_tree = mock_crawl_success)
    spi_update_inventory("master")
    spi_update_inventory("SPI2023")
    spi_clear_inventory()
    remaining <- list.files(.spi_cache_dir(), pattern = "^tree_.*\\.rds$")
    expect_equal(length(remaining), 0L)
  })

  it("does not error when clearing a non-existent version's cache", {
    local_inventory_cache()
    expect_no_error(spi_clear_inventory("nonexistent"))
  })

  it("does not error when clearing an already-empty cache", {
    local_inventory_cache()
    expect_no_error(spi_clear_inventory())
  })

  it("rejects a non-character version argument", {
    expect_error(spi_clear_inventory(version = 123), "`version`")
  })

  it("only deletes the specified version, leaving others intact", {
    local_inventory_cache()
    local_mocked_bindings(.spi_crawl_tree = mock_crawl_success)
    spi_update_inventory("master")
    spi_update_inventory("SPI2023")
    spi_clear_inventory("master")
    expect_false(file.exists(.spi_cache_path("master")))
    expect_true(file.exists(.spi_cache_path("SPI2023")))
  })
})

# ---------------------------------------------------------------------------
# 5. Lifecycle: full workflow integration
# ---------------------------------------------------------------------------

describe("Lifecycle: full cache workflow", {
  it("runs the full lifecycle: miss → hit → force-update → clear → error", {
    local_inventory_cache()

    # Step 1: cache miss → crawl → write
    local_mocked_bindings(.spi_crawl_tree = mock_crawl_success)
    r1 <- .spi_get_inventory("master")
    expect_s3_class(r1, "data.table")
    expect_true(file.exists(.spi_cache_path("master")))

    # Step 2: cache hit → no crawl (fail mock must NOT be triggered)
    local_mocked_bindings(.spi_crawl_tree = mock_crawl_fail)
    expect_s3_class(.spi_get_inventory("master"), "data.table")

    # Step 3: force update (success mock)
    local_mocked_bindings(.spi_crawl_tree = mock_crawl_success)
    expect_no_error(spi_update_inventory("master"))
    expect_true(file.exists(.spi_cache_path("master")))

    # Step 4: clear
    spi_clear_inventory("master")
    expect_false(file.exists(.spi_cache_path("master")))

    # Step 5: no cache + no network → informative error
    local_mocked_bindings(.spi_crawl_tree = mock_crawl_fail)
    expect_error(.spi_get_inventory("master"), "No cached inventory found")
  })

  it("handles two versions cached simultaneously and clears independently", {
    local_inventory_cache()
    local_mocked_bindings(.spi_crawl_tree = mock_crawl_success)

    .spi_get_inventory("master")
    .spi_get_inventory("SPI2023")

    expect_true(file.exists(.spi_cache_path("master")))
    expect_true(file.exists(.spi_cache_path("SPI2023")))

    spi_clear_inventory("SPI2023")
    expect_true(file.exists(.spi_cache_path("master")))
    expect_false(file.exists(.spi_cache_path("SPI2023")))

    spi_clear_inventory()
    expect_false(file.exists(.spi_cache_path("master")))
  })
})
