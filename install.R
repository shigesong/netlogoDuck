#!/usr/bin/env Rscript
# Install netlogoDuck and its dependencies.
#
# Usage:
#   Rscript install.R            # install this directory
#   Rscript install.R /path/pkg  # install another checkout

options(repos = c(CRAN = "https://cloud.r-project.org"), warn = 1)

fail <- function(...) {
  message("ERROR: ", ...)
  quit(status = 1L)
}

if (getRversion() < "4.1.0") {
  fail("R >= 4.1.0 is required; found ", getRversion())
}

args <- commandArgs(trailingOnly = TRUE)
pkg_dir <- normalizePath(if (length(args) >= 1L) args[[1L]] else ".", mustWork = FALSE)
if (!file.exists(file.path(pkg_dir, "DESCRIPTION"))) {
  fail("No DESCRIPTION found in ", pkg_dir)
}

install_missing <- function(pkgs, ...) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) == 0L) {
    return(invisible(NULL))
  }
  message("Installing: ", paste(missing, collapse = ", "))
  install.packages(missing, ...)
  still_missing <- missing[!vapply(missing, requireNamespace, logical(1), quietly = TRUE)]
  if (length(still_missing) > 0L) {
    fail("Failed to install: ", paste(still_missing, collapse = ", "))
  }
}

install_missing(c("DBI", "duckdb", "duckplyr", "dplyr"))

# logolink is not on CRAN.
if (!requireNamespace("logolink", quietly = TRUE)) {
  install_missing("remotes")
  message("Installing logolink from GitHub (danielvartan/logolink) ...")
  remotes::install_github("danielvartan/logolink", upgrade = "never")
  if (!requireNamespace("logolink", quietly = TRUE)) {
    fail("Failed to install logolink")
  }
}

# Suggested packages, needed to run the test suite.
install_missing(c("testthat", "withr"))

message("Installing netlogoDuck from ", pkg_dir, " ...")
status <- system2(
  file.path(R.home("bin"), "R"),
  c("CMD", "INSTALL", "--no-multiarch", shQuote(pkg_dir))
)
if (status != 0L) {
  fail("R CMD INSTALL failed with status ", status)
}

if (!requireNamespace("netlogoDuck", quietly = TRUE)) {
  fail("netlogoDuck was installed but cannot be loaded")
}

message("netlogoDuck installed successfully.")

# logolink needs a NetLogo installation; report it now rather than at run time.
console <- tryCatch(
  suppressWarnings(logolink::find_netlogo_console()),
  error = function(e) NA_character_
)
if (is.na(console)) {
  warning(
    "NetLogo >= 7.0.1 was not found. Set NETLOGO_HOME (installation directory) ",
    "or NETLOGO_CONSOLE (console executable) before running experiments.",
    call. = FALSE
  )
} else {
  message("Found NetLogo console: ", console)
}

message("Done. Load it with: library(netlogoDuck)")
