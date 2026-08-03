#' spiR: Statistical Performance Indicators Data Access
#'
#' Access World Bank Statistical Performance Indicators (SPI) data from
#' GitHub. Provides [spi_get()], [spi_data()], [spi_index()], and
#' [spi_aggregates()] to retrieve and filter the core SPI output datasets.
#'
#' @importFrom cli cli_abort cli_warn
#' @importFrom data.table data.table as.data.table fread :=
#' @importFrom httr2 request req_headers req_error req_perform resp_body_json resp_status
#' @keywords internal
"_PACKAGE"

## Suppress R CMD check notes about data.table's non-standard evaluation
## (.SD, :=, etc.) and ggplot2/data.table column names that appear as global
## variables in unquoted expressions.
utils::globalVariables(c(
  ".", ".SD",
  # data.table / ggplot2 column symbols used in NSE expressions
  "value", "value_plot", "pillar", "date", "country", "country_label",
  "iso3c", "iso3", "source_id", "region", "series", "highlighted",
  "hover_text", "dimension", "category",
  # metadata column symbols
  "pillar_id", "pillar_name", "pillar_description",
  "dimension_id", "dimension_name", "dimension_description",
  "indicator", "indicator_id", "indicator_name", "indicator_description",
  "indicator_scoring", "indicator_abv"
))
