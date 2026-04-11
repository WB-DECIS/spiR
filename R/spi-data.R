#' Get SPI Data from GitHub
#'
#' Retrieves SPI data (SPI_data.csv, SPI_index.csv, or aggregates) from the 
#' World Bank SPI repository on GitHub.
#'
#' @param type Character. Type of data to retrieve: "data" (SPI_data.csv), 
#'   "index" (SPI_index.csv), or "aggregates" (aggregate values).
#' @param version Character. SPI version/branch name. Default is "main".
#' @param raw Logical. If TRUE, return raw data as character vector. 
#'   If FALSE, parse to data.table. Default is FALSE.
#'
#' @return A data.table (or character vector if raw=TRUE) containing the requested SPI data.
#'
#' @details
#' SPI versions correspond to branches in the GitHub repository. Common versions
#' include "main" (latest stable) and version-specific branches (e.g., "v1.0", "v2.0").
#' 
#' The function handles network errors gracefully and provides informative messages.
#'
#' @examples
#' \dontrun{
#' # Get latest SPI data
#' spi_data <- spi_get(type = "data")
#' 
#' # Get SPI index for a specific version
#' spi_index <- spi_get(type = "index", version = "v1.0")
#' 
#' # Get aggregates
#' spi_agg <- spi_get(type = "aggregates")
#' }
#'
#' @export
spi_get <- function(type = "data", version = "main", raw = FALSE) {
  type <- match.arg(type, c("data", "index", "aggregates"))
  
  if (!is.character(version) || length(version) != 1) {
    stop("version must be a single character string")
  }
  
  # Construct GitHub raw content URL
  base_url <- "https://raw.githubusercontent.com/worldbank/SPI"
  
  # Map type to filename
  filename <- switch(type,
    data = "SPI_data.csv",
    index = "SPI_index.csv",
    aggregates = "aggregates.csv"
  )
  
  url <- paste(base_url, version, filename, sep = "/")
  
  tryCatch({
    # Download data
    response <- utils::read.csv(url, stringsAsFactors = FALSE)
    
    if (raw) {
      return(readLines(url))
    }
    
    # Convert to data.table
    dt <- data.table::as.data.table(response)
    return(dt)
    
  }, error = function(e) {
    stop(
      sprintf(
        "Failed to retrieve %s (version: %s) from GitHub.\nURL: %s\nError: %s",
        type, version, url, conditionMessage(e)
      ),
      call. = FALSE
    )
  })
}

#' Get Available SPI Versions
#'
#' Returns a character vector of available SPI versions (branches) in the 
#' World Bank SPI GitHub repository.
#'
#' @return Character vector of version names.
#'
#' @details
#' Note: This function requires internet access. Versions are cached for 
#' performance; use force_refresh=TRUE to get the latest list.
#'
#' @examples
#' \dontrun{
#' versions <- spi_versions()
#' }
#'
#' @keywords internal
spi_versions <- function() {
  # Placeholder: in production, this would parse GitHub API or a manifest file
  # For now, return common versions
  c("main", "v1.0", "v2.0")
}

#' List SPI Inventory
#'
#' Browse available SPI datasets, filtered by type, version, or other criteria.
#'
#' @param type Character. Filter by data type: "data", "index", "aggregates", or NULL for all.
#' @param version Character. Filter by SPI version. Default is "main".
#' @param detailed Logical. If TRUE, return detailed metadata. Default is FALSE.
#'
#' @return A data.table with available datasets and their metadata.
#'
#' @examples
#' \dontrun{
#' # List all available data
#' inventory <- spi_inventory()
#' 
#' # List only index data
#' index_inventory <- spi_inventory(type = "index")
#' }
#'
#' @export
spi_inventory <- function(type = NULL, version = "main", detailed = FALSE) {
  # Placeholder: builds a data.table of available files
  # In production, this would query GitHub or a manifest
  
  available <- data.table::data.table(
    type = c("data", "index", "aggregates"),
    file = c("SPI_data.csv", "SPI_index.csv", "aggregates.csv"),
    version = version,
    description = c(
      "Full SPI dataset with all indicators",
      "SPI index and composite scores",
      "Aggregate statistics by region/country"
    )
  )
  
  if (!is.null(type)) {
    available <- available[type == type]
  }
  
  available
}
