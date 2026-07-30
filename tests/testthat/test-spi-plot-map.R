make_mock_boundaries_sf <- function() {
  p1 <- sf::st_polygon(list(matrix(
    c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
    ncol = 2,
    byrow = TRUE
  )))
  p2 <- sf::st_polygon(list(matrix(
    c(2, 0, 3, 0, 3, 1, 2, 1, 2, 0),
    ncol = 2,
    byrow = TRUE
  )))

  sf::st_sf(
    iso3 = c("CHL", "PER"),
    country = c("Chile", "Peru"),
    geometry = sf::st_sfc(p1, p2, crs = 4326)
  )
}

make_mock_plot_values <- function() {
  data.table::data.table(
    iso3c = c("CHL", "PER"),
    date = c(2024L, 2024L),
    country = c("Chile", "Peru"),
    value = c(70, 60)
  )
}

test_that("spi_plot_map() returns ggplot when interactive = FALSE", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("wbplot")
  skip_if_not_installed("sf")

  local_mocked_bindings(
    .spi_plot_check_deps = function(pkgs) invisible(NULL),
    .spi_plot_fetch = function(...) make_mock_plot_values(),
    .spi_fetch_boundaries = function(resolution = "medium") make_mock_boundaries_sf()
  )

  out <- spi_plot_map(
    value_col = "SPI.INDEX",
    year = 2024L,
    interactive = FALSE
  )

  expect_s3_class(out, "ggplot")
})

test_that("spi_plot_map() returns girafe when interactive = TRUE", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("wbplot")
  skip_if_not_installed("sf")
  skip_if_not_installed("ggiraph")

  local_mocked_bindings(
    .spi_plot_check_deps = function(pkgs) invisible(NULL),
    .spi_plot_fetch = function(...) make_mock_plot_values(),
    .spi_fetch_boundaries = function(resolution = "medium") make_mock_boundaries_sf()
  )

  out <- spi_plot_map(
    value_col = "SPI.INDEX",
    year = 2024L,
    interactive = TRUE
  )

  expect_true(inherits(out, "girafe"))
})
