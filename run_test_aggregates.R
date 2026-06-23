# Install dependencies
packages_needed <- c("cli", "data.table", "httr2", "tools", "utils")
for (pkg in packages_needed) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg, repos = "http://cran.r-project.org", quiet = TRUE)
    library(pkg, character.only = TRUE)
  }
}

# Source the package files
source("R/spiR-package.R")
source("R/spi-download.R")
source("R/spi-github.R")
source("R/spi-inventory-cache.R")
source("R/spi-filters.R")
source("R/spi-wrappers.R")
source("R/spi-data.R")

# Run the test with two indicators
r2 <- spi_aggregates(region = "Africa Eastern and Southern", pillar = 3)

cat("Result:\n")
print(r2)

cat("\nStructure:\n")
str(r2)

cat("\nColumn names:\n")
print(names(r2))

cat("\nDimensions:\n")
print(dim(r2))

cat("\nClass:\n")
print(class(r2))
