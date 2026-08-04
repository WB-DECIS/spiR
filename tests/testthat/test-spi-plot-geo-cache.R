make_geo_cache_sf <- function() {
  polygon <- sf::st_polygon(list(matrix(
    c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
    ncol = 2,
    byrow = TRUE
  )))

  sf::st_sf(
    iso3 = "CHL",
    country = "Chile",
    geometry = sf::st_sfc(polygon, crs = 4326)
  )
}

test_that(".spi_geo_write_cache() and .spi_geo_read_cache() round-trip a valid sf cache", {
  skip_if_not_installed("sf")

  tmp <- withr::local_tempdir()
  local_mocked_bindings(
    .spi_geo_cache_dir = function() tmp,
    .package = "spiR"
  )

  geo_sf <- make_geo_cache_sf()
  .spi_geo_write_cache(geo_sf, "medium")
  out <- .spi_geo_read_cache("medium")

  expect_s3_class(out, "sf")
  expect_equal(out$iso3, "CHL")
})

test_that(".spi_geo_read_cache() invalidates schema mismatches", {
  skip_if_not_installed("sf")

  tmp <- withr::local_tempdir()
  local_mocked_bindings(
    .spi_geo_cache_dir = function() tmp,
    .package = "spiR"
  )

  bad_obj <- list(
    schema_version = 999L,
    timestamp = Sys.time(),
    sf = make_geo_cache_sf()
  )

  saveRDS(bad_obj, file = .spi_geo_cache_path("medium"), compress = FALSE)
  out <- .spi_geo_read_cache("medium")

  expect_null(out)
  expect_false(file.exists(.spi_geo_cache_path("medium")))
})