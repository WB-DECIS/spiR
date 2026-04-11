# GitHub API helpers for the spiR package.

# ---------------------------------------------------------------------------
# Internal HTTP helper (mockable in tests)
# ---------------------------------------------------------------------------

#' Internal: GET a GitHub API endpoint and return the parsed JSON body
#'
#' Thin wrapper around httr2 so that tests can mock one well-defined function
#' instead of the lower-level httr2 machinery.
#'
#' @param url Character. Full URL to the GitHub API endpoint.
#' @return A list parsed from the JSON response body.
#' @keywords internal
.spi_github_get_json <- function(url) {
  resp <- tryCatch(
    httr2::request(url) |>
      httr2::req_headers("User-Agent" = "spiR R package (https://github.com/WB-DECIS/spiR)") |>
      httr2::req_error(is_error = \(r) FALSE) |>
      httr2::req_perform(),
    error = function(e) {
      cli::cli_abort(c(
        "Failed to connect to the GitHub API.",
        "x" = "Caused by: {conditionMessage(e)}",
        "i" = "URL: {url}"
      ))
    }
  )

  status <- httr2::resp_status(resp)
  if (status != 200L) {
    cli::cli_abort(c(
      "GitHub API returned an error.",
      "x" = "HTTP status: {status}",
      "i" = "URL: {url}"
    ))
  }

  httr2::resp_body_json(resp)
}

# ---------------------------------------------------------------------------
# spi_versions()
# ---------------------------------------------------------------------------

#' List available SPI versions (branches)
#'
#' Queries the GitHub API for all branches in the World Bank SPI repository.
#' Each branch corresponds to a version of the SPI data that can be passed
#' as the `version` argument to [spi_get()].
#'
#' @return A sorted character vector of branch names. `"master"` (the
#'   latest stable version) is always included.
#'
#' @seealso [spi_get()]
#'
#' @examples
#' \dontrun{
#' spi_versions()
#' }
#'
#' @export
spi_versions <- function() {
  url <- "https://api.github.com/repos/worldbank/SPI/branches?per_page=100"

  branches <- .spi_github_get_json(url)

  if (length(branches) == 0L) {
    cli::cli_abort("Could not parse branch names from the GitHub API response.")
  }

  branch_names <- vapply(branches, `[[`, character(1L), "name")

  # Warn if the result may be truncated (GitHub's per-page ceiling is 100).
  if (length(branch_names) == 100L) {
    cli::cli_warn(c(
      "SPI version list may be incomplete.",
      "i" = "The GitHub API returned exactly 100 branches (the maximum per page)."
    ))
  }

  # Guarantee that "master" is always in the result per the documented contract.
  sort(union(branch_names, "master"))
}
