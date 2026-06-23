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
cat("Running: r1 <- spi_indicator(c('SPI.D5.2.2.NABY', 'SPI.D1.5.POV'), country = 'CHL', year = 2024)\n\n")
r1 <- spi_indicator(c("SPI.D5.2.2.NABY", "SPI.D1.5.POV"), country = "CHL", year = 2024)

cat("Result:\n")
print(r1)

cat("\nStructure:\n")
str(r1)

cat("\nColumn names:\n")
print(names(r1))

cat("\nDimensions:\n")
print(dim(r1))

cat("\nClass:\n")
print(class(r1))
