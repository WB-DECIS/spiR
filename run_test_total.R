# Run quick smoke tests for all spi wrapper functions and print compact outputs.

load_spir_code <- function() {
  if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all(".", quiet = TRUE)
    return(invisible(TRUE))
  }

  source("R/spiR-package.R")
  source("R/spi-download.R")
  source("R/spi-github.R")
  source("R/spi-inventory-cache.R")
  source("R/spi-filters.R")
  source("R/spi-wrappers.R")
  source("R/spi-data.R")
  invisible(TRUE)
}

print_result <- function(name, expr) {
  cat("\n", paste(rep("=", 78), collapse = ""), "\n", sep = "")
  cat("TEST:", name, "\n")
  cat(paste(rep("-", 78), collapse = ""), "\n", sep = "")

  out <- tryCatch(expr, error = function(e) e)

  if (inherits(out, "error")) {
    cat("STATUS: ERROR\n")
    cat("MESSAGE:", conditionMessage(out), "\n")
    return(invisible(NULL))
  }

  cat("STATUS: OK\n")
  cat("CLASS:", paste(class(out), collapse = ", "), "\n")
  cat("DIM:", paste(dim(out), collapse = " x "), "\n")
  cat("COLUMNS:\n")
  print(names(out))
  cat("PREVIEW (first rows):\n")
  print(utils::head(out, 5))

  invisible(out)
}

load_spir_code()

# Adjust these inputs if needed.
version_to_test <- "master"
country_to_test <- "CHL"
year_to_test <- 2024L
pillar_to_test <- 1L
dimension_to_test <- "1.5"
region_to_test <- "Africa Eastern and Southern"
indicator_to_test <- c("SPI.D5.2.2.NABY", "SPI.D1.5.POV")

print_result(
  "spi_data()",
  spi_data(
    version = version_to_test,
    country = country_to_test,
    year = year_to_test,
    pillar = pillar_to_test,
    dimension = dimension_to_test
  )
)

print_result(
  "spi_index()",
  spi_index(
    version = version_to_test,
    country = country_to_test,
    year = year_to_test,
    pillar = pillar_to_test,
    dimension = dimension_to_test
  )
)

print_result(
  "spi_aggregates()",
  spi_aggregates(
    version = version_to_test,
    region = region_to_test,
    year = year_to_test,
    pillar = pillar_to_test,
    dimension = dimension_to_test
  )
)

print_result(
  "spi_indicator()",
  spi_indicator(
    indicator = indicator_to_test,
    version = version_to_test,
    country = country_to_test,
    year = year_to_test,
    include_raw = FALSE
  )
)

cat("\nDone.\n")
