# Map utilities and plotting for SPI visualization.

SPI_PLOT_GEO_CACHE_SCHEMA_VERSION <- 1L
SPI_PLOT_GEO_CACHE_TTL_DAYS <- 30L

#' Geometry cache directory for SPI plotting maps
#' @keywords internal
.spi_geo_cache_dir <- function() {
  dir <- tools::R_user_dir("spiR", "cache")
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }
  return(dir)
}

#' Geometry cache path for a map resolution
#' @param resolution Character map resolution key.
#' @keywords internal
.spi_geo_cache_path <- function(resolution) {
  if (!is.character(resolution) || length(resolution) != 1L || is.na(resolution)) {
    cli::cli_abort("{.arg resolution} must be a single character value.")
  }

  if (grepl("[/\\\\]", resolution)) {
    cli::cli_abort(c(
      "{.arg resolution} must not contain path separators.",
      "x" = "Got {.val {resolution}}."
    ))
  }

  file.path(.spi_geo_cache_dir(), paste0("wb_boundaries_", resolution, ".rds"))
}

#' Read boundaries geometry cache
#' @param resolution Character map resolution key.
#' @keywords internal
.spi_geo_read_cache <- function(resolution) {
  path <- .spi_geo_cache_path(resolution)
  if (!file.exists(path)) {
    return(NULL)
  }

  obj <- tryCatch(readRDS(path), error = function(e) NULL)
  if (is.null(obj) || !is.list(obj)) {
    unlink(path)
    return(NULL)
  }

  required <- c("schema_version", "timestamp", "sf")
  if (!all(required %in% names(obj))) {
    unlink(path)
    return(NULL)
  }

  if (!identical(obj$schema_version, SPI_PLOT_GEO_CACHE_SCHEMA_VERSION)) {
    unlink(path)
    return(NULL)
  }

  if (!inherits(obj$timestamp, "POSIXct")) {
    unlink(path)
    return(NULL)
  }

  age_days <- as.numeric(difftime(Sys.time(), obj$timestamp, units = "days"))
  if (!is.finite(age_days) || age_days < 0 || age_days > SPI_PLOT_GEO_CACHE_TTL_DAYS) {
    return(NULL)
  }

  if (!inherits(obj$sf, "sf")) {
    unlink(path)
    return(NULL)
  }

  return(obj$sf)
}

#' Write boundaries geometry cache
#' @param geo_sf sf object.
#' @param resolution Character map resolution key.
#' @keywords internal
.spi_geo_write_cache <- function(geo_sf, resolution) {
  if (!inherits(geo_sf, "sf")) {
    cli::cli_abort("{.arg geo_sf} must be an {.cls sf} object.")
  }

  path <- .spi_geo_cache_path(resolution)
  obj <- list(
    schema_version = SPI_PLOT_GEO_CACHE_SCHEMA_VERSION,
    timestamp = Sys.time(),
    sf = geo_sf
  )

  saveRDS(obj, file = path, compress = FALSE)
  invisible(geo_sf)
}

#' Resolve ISO and country name columns from boundary source
#' @param geo_sf sf object from ArcGIS source.
#' @keywords internal
.spi_boundary_standardize <- function(geo_sf) {
  nms <- names(geo_sf)

  iso_col <- nms[grepl("^(ISO_A3|WB_A3|ISO3|ISO_3|ISO_A3_EH)$", nms, ignore.case = TRUE)][1]
  if (is.na(iso_col)) {
    cli::cli_abort(c(
      "Could not identify an ISO3 column in boundaries source.",
      "x" = "Available columns: {.field {nms}}"
    ))
  }

  name_col <- nms[grepl("^(NAM_0|WB_NAME|NAME_EN|NAME|ADMIN|COUNTRY)$", nms, ignore.case = TRUE)][1]

  out <- data.table::as.data.table(geo_sf)
  out[, iso3 := toupper(trimws(as.character(get(iso_col))))]
  if (!is.na(name_col)) {
    out[, country := as.character(get(name_col))]
  } else {
    out[, country := iso3]
  }

  out <- out[!is.na(iso3) & nchar(iso3) == 3L & iso3 != "-99"]

  sf::st_as_sf(out[, c("iso3", "country", attr(geo_sf, "sf_column")), with = FALSE])
}

#' Fetch WB boundaries from ArcGIS API with local cache fallback
#' @param resolution Character scalar: "medium" or "high".
#' @keywords internal
.spi_fetch_boundaries <- function(resolution = "medium") {
  .spi_plot_check_deps(c("sf", "httr2"))

  resolution <- match.arg(resolution, c("medium", "high"))

  cached <- .spi_geo_read_cache(resolution)
  if (!is.null(cached)) {
    return(cached)
  }

  layer_info <- if (resolution == "medium") {
    list(service = "WB_GAD_Medium_Resolution", layer_id = 5L)
  } else {
    list(service = "WB_GAD_ADM0", layer_id = 0L)
  }

  url <- paste0(
    "https://services.arcgis.com/iQ1dY19aHwbSDYIF/arcgis/rest/services/",
    layer_info$service,
    "/FeatureServer/",
    layer_info$layer_id,
    "/query?where=1%3D1&outFields=*&f=geojson"
  )

  tmp <- tempfile(fileext = ".geojson")
  on.exit(unlink(tmp), add = TRUE)

  geo_sf <- tryCatch({
    resp <- httr2::request(url) |>
      httr2::req_perform()
    writeBin(httr2::resp_body_raw(resp), tmp)
    sf::st_read(tmp, quiet = TRUE)
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to download WB boundaries and no valid local cache exists.",
      "x" = "Caused by: {conditionMessage(e)}",
      "i" = "Endpoint: {url}"
    ), parent = e)
  })

  geo_sf <- .spi_boundary_standardize(geo_sf)
  .spi_geo_write_cache(geo_sf, resolution)
  return(geo_sf)
}

#' Build map hover text
#' @param dt data.table with map values.
#' @param label Label shown in tooltip.
#' @param digits Integer digits for value formatting.
#' @keywords internal
.spi_map_hover <- function(dt, label, digits) {
  if (!data.table::is.data.table(dt)) {
    cli::cli_abort("{.arg dt} must be a {.cls data.table}.")
  }

  lbl <- if (is.null(label) || !nzchar(label)) "value" else label
  dt[, hover_text := paste0(
    country,
    " (", iso3, ")\n",
    lbl,
    ": ",
    ifelse(
      is.na(value_plot),
      "No data",
      format(round(value_plot, digits), nsmall = digits)
    )
  )]

  return(dt)
}

#' Clear cached map boundaries for one or all resolutions
#'
#' @param resolution Optional resolution key (`"medium"` or `"high"`).
#'   If `NULL`, clears all cached boundary files.
#' @return Invisible NULL.
#' @export
spi_clear_geo_cache <- function(resolution = NULL) {
  if (is.null(resolution)) {
    cache_dir <- .spi_geo_cache_dir()
    files <- list.files(
      cache_dir,
      pattern = "^wb_boundaries_.*\\.rds$",
      full.names = TRUE
    )

    if (length(files) > 0L) {
      unlink(files)
      cli::cli_inform("Map boundaries cache cleared ({length(files)} file{?s}).")
    } else {
      cli::cli_inform("Map boundaries cache is already empty.")
    }

    return(invisible(NULL))
  }

  resolution <- match.arg(resolution, c("medium", "high"))
  path <- .spi_geo_cache_path(resolution)
  if (file.exists(path)) {
    unlink(path)
    cli::cli_inform("Map boundaries cache cleared for {.val {resolution}}.")
  } else {
    cli::cli_inform("No map boundaries cache found for {.val {resolution}}.")
  }

  invisible(NULL)
}

#' Plot a world SPI choropleth for any SPI column
#'
#' Draws a world choropleth of a single SPI column for one year, styled with
#' the World Bank Data Visualization Style Guide. Countries can be
#' highlighted or zoomed, and the map can be returned as a static
#' [ggplot2::ggplot] or an interactive [ggiraph::girafe] widget.
#'
#' @param value_col Character scalar. SPI column to map (e.g.
#'   `"SPI.INDEX"`).
#' @param year Integer year to display.
#' @param country Optional ISO3 vector to highlight or zoom to.
#' @param zoom Logical. If `TRUE`, zoom to the selected countries.
#' @param interactive Logical. If `TRUE` (default) returns a
#'   [ggiraph::girafe] widget; if `FALSE` returns a [ggplot2::ggplot].
#' @param label Optional legend/title label. Defaults to `value_col`.
#' @param version Character. SPI branch. Defaults to `"master"`.
#' @param resolution Character map resolution (`"medium"` or `"high"`).
#'
#' @return A [ggplot2::ggplot] object (when `interactive = FALSE`) or a
#'   [ggiraph::girafe] widget (when `interactive = TRUE`).
#'
#' @seealso [spi_plot_trend()], [spi_clear_geo_cache()]
#'
#' @examples
#' \dontrun{
#' spi_plot_map("SPI.INDEX", year = 2023)
#' spi_plot_map("SPI.INDEX", year = 2023, country = "CHL", zoom = TRUE)
#' spi_plot_map("SPI.INDEX", year = 2023, interactive = FALSE)
#' }
#'
#' @export
spi_plot_map <- function(value_col,
                         year,
                         country = NULL,
                         zoom = FALSE,
                         interactive = TRUE,
                         label = NULL,
                         version = "master",
                         resolution = "medium") {
  .spi_plot_check_deps(c("ggplot2", "sf"))
  if (isTRUE(interactive)) {
    .spi_plot_check_deps("ggiraph")
  }

  if ((!is.numeric(year) && !is.integer(year)) || length(year) != 1L || is.na(year)) {
    cli::cli_abort("{.arg year} must be a single numeric/integer value.")
  }

  yr <- as.integer(year)
  values_dt <- .spi_plot_fetch(
    value_col = value_col,
    version = version,
    country = country,
    year = yr
  )

  scale_info <- .spi_plot_scale(values_dt$value)
  boundaries <- .spi_fetch_boundaries(resolution = resolution)

  values_dt[, iso3 := iso3c]
  map_dt <- merge(
    data.table::as.data.table(boundaries),
    values_dt[, .(iso3, date, value)],
    by = "iso3",
    all.x = TRUE,
    sort = FALSE
  )
  map_sf <- sf::st_as_sf(map_dt)

  sel <- NULL
  if (!is.null(country)) {
    if (!is.character(country) || anyNA(country)) {
      cli::cli_abort("{.arg country} must be a character vector with no NA values.")
    }
    sel <- unique(toupper(trimws(country)))
  }

  map_sf$highlighted <- if (is.null(sel)) TRUE else map_sf$iso3 %in% sel
  map_sf$value_plot <- if (!is.null(sel) && !isTRUE(zoom)) {
    data.table::fifelse(map_sf$highlighted, map_sf$value, NA_real_)
  } else {
    map_sf$value
  }

  if (!is.null(sel) && isTRUE(zoom)) {
    map_sf <- map_sf[map_sf$highlighted, ]
    if (nrow(map_sf) == 0L) {
      cli::cli_abort("No boundary polygons matched the requested country selection.")
    }
  }

  ttl <- if (is.null(label) || !nzchar(label)) value_col else label
  map_sf <- .spi_map_hover(data.table::as.data.table(map_sf), ttl, scale_info$digits)
  map_sf <- sf::st_as_sf(map_sf)

  p <- ggplot2::ggplot(map_sf)
  if (isTRUE(interactive)) {
    p <- p + ggiraph::geom_sf_interactive(
      ggplot2::aes(fill = value_plot, tooltip = hover_text, data_id = iso3),
      color = "#FFFFFF",
      linewidth = 0.1
    )
  } else {
    p <- p + ggplot2::geom_sf(
      ggplot2::aes(fill = value_plot),
      color = "#FFFFFF",
      linewidth = 0.1
    )
  }

  p <- p +
    .spi_scale_fill_wb_c(na.value = "#CED4DE") +
    ggplot2::labs(
      title = paste0(ttl, " | ", yr),
      fill = ttl,
      caption = SPI_PLOT_CAPTION
    ) +
    .spi_theme_wb("map") +
    ggplot2::theme(
      axis.text = ggplot2::element_blank(),
      axis.ticks = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank()
    )

  if (!isTRUE(interactive)) {
    return(p)
  }

  ggiraph::girafe(
    ggobj = p,
    options = list(
      ggiraph::opts_hover(css = "stroke:#111111;stroke-width:0.8px;"),
      ggiraph::opts_tooltip(css = paste0(
        "background:#FFFFFF;color:#111111;border:1px solid #CED4DE;",
        "padding:6px 8px;border-radius:4px;font-family:sans-serif;font-size:12px;"
      ))
    )
  )
}
