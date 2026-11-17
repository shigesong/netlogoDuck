#' Open a connection to a DuckDB database file
#'
#' Thin wrapper around [DBI::dbConnect()] with a `duckdb` driver. The
#' connection stays open until closed with [db_close()].
#'
#' @param db_path Path to a `.duckdb` database file. If the file does not
#'   exist yet it is created, along with any missing parent directories.
#'   Pass `":memory:"` for an in-memory database.
#' @param read_only Logical; open the database in read-only mode. Missing
#'   parent directories are not created, since the file must already exist.
#'
#' @return A `duckdb_connection` object.
#' @export
#'
#' @examples
#' con <- db_open(tempfile(fileext = ".duckdb"))
#' db_close(con)
db_open <- function(db_path, read_only = FALSE) {
  validate_path(db_path, "db_path", allow_memory = TRUE)
  if (!is_scalar_logical(read_only)) {
    stop("`read_only` must be one non-missing logical value.", call. = FALSE)
  }
  # DuckDB creates the file but never the directory tree above it.
  if (!read_only && !identical(db_path, ":memory:")) {
    dir <- dirname(db_path)
    if (!dir.exists(dir)) {
      dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    }
  }
  drv <- duckdb::duckdb()
  DBI::dbConnect(drv, dbdir = db_path, read_only = read_only)
}

#' Close a DuckDB connection
#'
#' @param con A connection created by [db_open()].
#'
#' @return Invisibly `NULL`.
#' @export
#'
#' @examples
#' con <- db_open(tempfile(fileext = ".duckdb"))
#' db_close(con)
db_close <- function(con) {
  validate_db_con(con)
  DBI::dbDisconnect(con, shutdown = TRUE)
  invisible(NULL)
}
