#' Import a NetLogo BehaviorSpace results CSV into DuckDB
#'
#' NetLogo BehaviorSpace CSVs start with several metadata lines (model path,
#' timestamp, world dimensions) before the real header row. This function
#' locates the header row (the one containing `[run number]`), skips the
#' preceding metadata, and loads the data into a DuckDB table.
#'
#' @param input Path to a BehaviorSpace results CSV.
#' @param output Path to the `.duckdb` database file. Defaults to `input`
#'   with the `.csv` extension replaced by `.duckdb`.
#' @param table Name of the table to create/replace.
#' @param quiet Logical; suppress progress messages.
#' @param db_con Optional: an existing connection from [db_open()]. If given,
#'   `output` is ignored and the connection is left open on exit.
#'
#' @return Invisibly, the number of rows imported.
#' @export
#'
#' @examples
#' \dontrun{
#' csv_to_duckdb("results/table-2026-08-11-19-47-33-373077.csv")
#' }
csv_to_duckdb <- function(input,
                          output = NULL,
                          table = "results",
                          quiet = FALSE,
                          db_con = NULL) {
  if (!is.character(input) || length(input) != 1L) {
    stop("`input` must be a single path string.", call. = FALSE)
  }
  if (!file.exists(input)) stop("input not found: ", input, call. = FALSE)
  if (is.null(output) && is.null(db_con)) {
    output <- sub("\\.csv$", ".duckdb", input)
  }

  log <- function(...) if (!quiet) message(...)

  skip <- find_header_line(input)

  log("Skipping ", skip, " lines before header")
  log("Importing ", input, " -> ", if (is.null(db_con)) output else "<db_con>",
      " (table: ", table, ")")

  con <- db_con
  close_after <- FALSE
  if (is.null(con)) {
    con <- db_open(output)
    close_after <- TRUE
  }

  n <- tryCatch(
    {
      DBI::dbExecute(con, paste0('DROP TABLE IF EXISTS "', table, '"'))
      q <- paste0(
        "CREATE TABLE \"", table, "\" AS ",
        "SELECT * FROM read_csv('", normalizePath(input, winslash = "/"), "', ",
        "header = true, skip = ", skip, ", delim = ',', quote = '\"', ",
        "types = {'[run number]' : 'INTEGER'});"
      )
      DBI::dbExecute(con, q)
      DBI::dbGetQuery(con, paste0('SELECT COUNT(*) FROM "', table, '"'))[[1L]]
    },
    finally = if (close_after) db_close(con) else NULL
  )

  log("Done: ", n, " rows in table '", table, "'")
  invisible(n)
}

#' Locate the BehaviorSpace header row
#'
#' @param input Path to a BehaviorSpace results CSV.
#' @return The number of lines to skip before the header row (0-based).
#' @keywords internal
#'
#' @examples
#' f <- tempfile(fileext = ".csv")
#' writeLines(c('"metadata"', '"[run number]","ticks"', '"1","0"'), f)
#' netlogoDuck:::find_header_line(f)
find_header_line <- function(input) {
  con_text <- file(input, open = "r")
  on.exit(close(con_text))
  skip <- 0L
  repeat {
    line <- readLines(con_text, n = 1L)
    if (length(line) == 0L) stop("no header row found in ", input, call. = FALSE)
    if (grepl("\\[run number\\]", line)) break
    skip <- skip + 1L
  }
  skip
}
