#' Read a results table as a lazy duckplyr frame
#'
#' Opens (or reuses) a DuckDB connection and returns the requested table as a
#' [duckplyr::read_tbl_duckdb()] lazy frame. All downstream `dplyr` verbs
#' (`filter()`, `summarise()`, ...) are pushed into DuckDB and only
#' materialized when you call `dplyr::collect()`.
#'
#' @param db_path Path to the `.duckdb` database file.
#' @param table Name of the table to read.
#' @param schema Database schema containing the table (default `"main"`).
#' @param collect Logical; if `TRUE`, return a local tibble via
#'   `dplyr::collect()` instead of a lazy frame.
#'
#' @return A `duckplyr_df` (or a tibble if `collect = TRUE`).
#' @export
#'
#' @examples
#' \dontrun{
#' df <- read_results("results/demo.duckdb")
#' df |> dplyr::filter(experiment == "demo") |> dplyr::count()
#' }
read_results <- function(db_path,
                         table = "results",
                         schema = "main",
                         collect = FALSE) {
  if (!is.character(db_path) || length(db_path) != 1L) {
    stop("`db_path` must be a single path string.", call. = FALSE)
  }
  if (!file.exists(db_path)) {
    stop("database file not found: ", db_path, call. = FALSE)
  }
  if (!is.character(table) || length(table) != 1L) {
    stop("`table` must be a single string.", call. = FALSE)
  }

  out <- duckplyr::read_tbl_duckdb(
    path       = db_path,
    table_name = table,
    schema     = schema
  )
  if (collect) out <- dplyr::collect(out)
  out
}
