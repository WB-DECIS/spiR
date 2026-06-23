required_pkgs <- c("cli", "data.table", "httr2", "writexl")

for (pkg in required_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
}

library(data.table)

source("R/spiR-package.R")
source("R/spi-download.R")
source("R/spi-github.R")
source("R/spi-inventory-cache.R")
source("R/spi-filters.R")
source("R/spi-wrappers.R")
source("R/spi-data.R")

# Build catalog from SPI indicator columns
DT <- spi_data(version = "master")
indicator_cols <- grep("^SPI\\.D[0-9]+\\.[0-9]+\\.", names(DT), value = TRUE)

catalog <- data.table::data.table(indicator = indicator_cols)
catalog[, pillar := sub("^SPI\\.D([0-9]+)\\..*$", "\\1", indicator)]
catalog[, dimension := sub("^SPI\\.D([0-9]+\\.[0-9]+)\\..*$", "\\1", indicator)]
data.table::setcolorder(catalog, c("pillar", "dimension", "indicator"))
catalog[, pillar_num := as.integer(pillar)]
data.table::setorder(catalog, pillar_num, dimension, indicator)
catalog[, pillar_num := NULL]

pillars <- data.table::data.table(pillar = sort(unique(catalog$pillar)))
dimensions <- data.table::data.table(dimension = sort(unique(catalog$dimension)))

writexl::write_xlsx(
  x = list(
    indicators_catalog = catalog,
    pillars = pillars,
    dimensions = dimensions
  ),
  path = "spi_catalog.xlsx"
)

cat("Excel created: spi_catalog.xlsx\n")
