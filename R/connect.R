#' Open a connection to a DuckDB database file
#'
#' Thin wrapper around [DBI::dbConnect()] with a `duckdb` driver. The
#' connection stays open until closed with [db_close()].
#'
#' @param db_path Path to a `.duckdb` database file. If the file does not
#'   exist yet it is created. Pass `":memory:"` for an in-memory database.
#' @param read_only Logical; open the database in read-only mode.
#'
#' @return A `duckdb_connection` object.
#' @export
#'
#' @examples
#' con <- db_open(tempfile(fileext = ".duckdb"))
#' db_close(con)
db_open <- function(db_path, read_only = FALSE) {
  if (!is.character(db_path) || length(db_path) != 1L) {
    stop("`db_path` must be a single path string.", call. = FALSE)
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
  if (!inherits(con, "duckdb_connection")) {
    stop("`con` must be a duckdb connection from db_open().", call. = FALSE)
  }
  DBI::dbDisconnect(con, shutdown = TRUE)
  invisible(NULL)
}
