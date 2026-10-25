# Internal argument validation helpers ---------------------------------------

is_scalar_logical <- function(x) {
  is.logical(x) && length(x) == 1L && !is.na(x)
}

is_positive_integerish <- function(x) {
  is.numeric(x) && length(x) == 1L && is.finite(x) &&
    x >= 1 && x == floor(x) && x <= .Machine$integer.max
}

is_nonnegative_integerish <- function(x) {
  is.numeric(x) && length(x) == 1L && is.finite(x) &&
    x >= 0 && x == floor(x) && x <= .Machine$integer.max
}

validate_string <- function(x, arg, allow_empty = FALSE) {
  valid <- is.character(x) && length(x) == 1L && !is.na(x)
  if (!allow_empty) valid <- valid && nzchar(x)
  if (!valid) {
    description <- if (allow_empty) "a single string" else "a single non-empty string"
    stop("`", arg, "` must be ", description, ".", call. = FALSE)
  }
  invisible(x)
}

validate_named_list <- function(x, arg, allow_null = FALSE) {
  if (allow_null && is.null(x)) return(invisible(x))
  if (!is.list(x) || (length(x) > 0L && is.null(names(x))) ||
      anyNA(names(x)) ||
      any(!nzchar(names(x))) || anyDuplicated(names(x))) {
    stop("`", arg, "` must be a named list with unique, non-empty names.",
         call. = FALSE)
  }
  invisible(x)
}

validate_metrics <- function(metrics) {
  if (!is.character(metrics) || length(metrics) == 0L || anyNA(metrics) ||
      any(!nzchar(metrics)) || anyDuplicated(metrics)) {
    stop("`metrics` must be a non-empty character vector with unique, non-empty values.",
         call. = FALSE)
  }
  invisible(metrics)
}

validate_sub_experiments <- function(sub_experiments) {
  if (is.null(sub_experiments)) return(invisible(NULL))
  if (!is.list(sub_experiments)) {
    stop("`sub_experiments` must be NULL or a list of named lists.", call. = FALSE)
  }
  valid <- vapply(
    sub_experiments,
    function(x) is.list(x) && !is.null(names(x)) &&
      !anyNA(names(x)) && all(nzchar(names(x))) && !anyDuplicated(names(x)),
    logical(1)
  )
  if (length(valid) > 0L && !all(valid)) {
    stop("each element of `sub_experiments` must be a named list with unique, non-empty names.",
         call. = FALSE)
  }
  invisible(sub_experiments)
}

validate_metadata <- function(metadata) {
  validate_named_list(metadata, "metadata", allow_null = TRUE)
  if (!is.null(metadata)) {
    scalar <- vapply(metadata, function(x) is.atomic(x) && length(x) == 1L, logical(1))
    if (length(scalar) > 0L && !all(scalar)) {
      stop("each value in `metadata` must be a single atomic value.", call. = FALSE)
    }
  }
  invisible(metadata)
}

validate_db_con <- function(db_con) {
  if (!inherits(db_con, "duckdb_connection") || !DBI::dbIsValid(db_con)) {
    stop("`db_con` must be a valid connection created by db_open().", call. = FALSE)
  }
  invisible(db_con)
}

validate_table <- function(table) {
  validate_string(table, "table")
}

validate_path <- function(path, arg, allow_memory = FALSE) {
  if (allow_memory && identical(path, ":memory:")) return(invisible(path))
  validate_string(path, arg)
}
