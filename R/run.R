#' Run a NetLogo experiment and append its results to DuckDB
#'
#' Runs an experiment defined with [define_experiment()] through
#' [logolink::run_experiment()] and appends the tidy results table to a
#' DuckDB database. Each call stamps a unique `run_id` and experiment
#' metadata columns on every row so repeated runs can be filtered later.
#'
#' @param experiment A `netlogo_experiment` object from [define_experiment()].
#' @param db_path Path to the `.duckdb` database file. Created if missing.
#' @param table Name of the results table in the database.
#' @param threads Number of threads passed to the NetLogo headless runner
#'   (via `other_arguments = "--threads N"`).
#' @param timeout Maximum time in seconds to wait for NetLogo (see
#'   [logolink::run_experiment()]).
#' @param metadata Optional named list of extra values stamped on every row
#'   (e.g. `list(design = "H6")`).
#' @param smoke Logical; if `TRUE`, forces 1 repetition and 5 ticks for a
#'   quick validation run without editing the experiment object.
#' @param output Additional logolink output types, appended to `"table"`
#'   (e.g. `"lists"` for NetLogo list metrics).
#' @param tidy_output Passed to [logolink::run_experiment()].
#' @param db_con Optional: an existing connection from [db_open()]. If given,
#'   `db_path` is ignored and the connection is left open on exit.
#'
#' @return Invisibly, the number of rows appended to the database.
#' @export
#'
#' @examples
#' \dontrun{
#' xp <- define_experiment("demo", "src/monty_hall_spatial_rev12.nlogox",
#'                         metrics = c("avg-hunch", "win-rate"),
#'                         constants = list("agent-density" = 50),
#'                         repetitions = 5, time_limit = 50)
#' run_experiment_to_duckdb(xp, "results/demo.duckdb")
#' }
run_experiment_to_duckdb <- function(experiment,
                                     db_path,
                                     table = "results",
                                     threads = 4L,
                                     timeout = Inf,
                                     metadata = NULL,
                                     smoke = FALSE,
                                     output = "table",
                                     tidy_output = TRUE,
                                     db_con = NULL) {
  stopifnot(inherits(experiment, "netlogo_experiment"))
  if (!is.character(table) || length(table) != 1L) {
    stop("`table` must be a single string.", call. = FALSE)
  }

  # Smoke mode: 1 rep x 5 ticks, without mutating the caller's object.
  if (smoke) {
    experiment <- define_experiment(
      name                = experiment$name,
      model               = experiment$model,
      metrics             = experiment$spec$metrics,
      constants           = experiment$spec$constants,
      sub_experiments     = experiment$spec$sub_experiments,
      repetitions         = 1L,
      time_limit          = 5L,
      run_metrics_every_step = FALSE
    )
  }

  if (!is.null(metadata)) {
    if (!is.list(metadata) || is.null(names(metadata))) {
      stop("`metadata` must be a named list.", call. = FALSE)
    }
  }

  other_args <- c(paste("--threads", threads))

  message("[", experiment$name, "] running ", experiment$spec$repetitions,
          " reps x ", experiment$spec$time_limit, " ticks ...")
  res <- tryCatch(
    logolink::run_experiment(
      model_path      = experiment$model,
      setup_file      = experiment$setup_file,
      output          = output,
      other_arguments = other_args,
      timeout         = timeout,
      tidy_output     = tidy_output
    ),
    error = function(e) {
      warning("run_experiment() failed: ", conditionMessage(e), call. = FALSE)
      NULL
    }
  )

  if (is.null(res) || is.null(res$table) || nrow(res$table) == 0L) {
    message("No rows produced; nothing appended.")
    return(invisible(0L))
  }

  tab <- as.data.frame(res$table)

  # Stamp run metadata as flat columns.
  run_id  <- paste0(experiment$name, "-", format(Sys.time(), "%Y%m%d-%H%M%S"))
  meta <- list(
    run_id      = run_id,
    experiment  = experiment$name,
    model_path  = experiment$model,
    timestamp   = as.character(Sys.time()),
    repetitions = experiment$spec$repetitions,
    time_limit  = experiment$spec$time_limit,
    threads     = threads
  )
  if (!is.null(metadata)) meta <- c(meta, metadata)
  tab <- bind_metadata(tab, meta)

  con <- db_con
  close_after <- FALSE
  if (is.null(con)) {
    con <- db_open(db_path)
    close_after <- TRUE
  }

  n <- tryCatch(
    append_to_duckdb(con, tab, table),
    finally = if (close_after) db_close(con) else NULL
  )

  message("[", experiment$name, "] appended ", n, " rows -> ", table)
  invisible(n)
}

#' Run a simulation from a single function call
#'
#' Convenience wrapper that defines and runs an experiment in one step.
#'
#' @param name Experiment name.
#' @param model Path to the NetLogo model file.
#' @param db_path Path to the `.duckdb` database file.
#' @inheritParams define_experiment
#' @inheritParams run_experiment_to_duckdb
#'
#' @return Invisibly, the number of rows appended.
#' @export
#'
#' @examples
#' \dontrun{
#' run_simulation(
#'   name = "demo",
#'   model = "model.nlogox",
#'   db_path = "results.duckdb",
#'   metrics = "ticks",
#'   repetitions = 1,
#'   time_limit = 5
#' )
#' }
run_simulation <- function(name,
                           model,
                           db_path,
                           metrics = c("ticks", "avg-hunch", "win-rate"),
                           constants = list(),
                           sub_experiments = NULL,
                           repetitions = 100L,
                           time_limit = 500L,
                           run_metrics_every_step = FALSE,
                           setup = "setup",
                           go = "go",
                           table = "results",
                           threads = 4L,
                           timeout = Inf,
                           metadata = NULL,
                           smoke = FALSE,
                           ...) {
  xp <- define_experiment(
    name = name,
    model = model,
    metrics = metrics,
    constants = constants,
    sub_experiments = sub_experiments,
    repetitions = repetitions,
    time_limit = time_limit,
    run_metrics_every_step = run_metrics_every_step,
    setup = setup,
    go = go,
    ...
  )
  run_experiment_to_duckdb(
    experiment = xp,
    db_path = db_path,
    table = table,
    threads = threads,
    timeout = timeout,
    metadata = metadata,
    smoke = smoke
  )
}

# --- internal helpers -------------------------------------------------------

bind_metadata <- function(tab, meta) {
  for (nm in names(meta)) {
    val <- meta[[nm]]
    if (is.atomic(val) && length(val) == 1L) {
      tab[[nm]] <- rep(val, nrow(tab))
    } else {
      tab[[nm]] <- I(rep(list(val), nrow(tab)))
    }
  }
  tab
}

append_to_duckdb <- function(con, tab, table) {
  if (!DBI::dbExistsTable(con, table)) {
    DBI::dbWriteTable(con, table, tab, temporary = FALSE)
    return(nrow(tab))
  }

  existing <- DBI::dbListFields(con, table)
  tab_cols <- names(tab)

  # New columns in `tab` not yet in the table -> widen the table.
  new_cols <- setdiff(tab_cols, existing)
  for (nm in new_cols) {
    DBI::dbExecute(con, paste0('ALTER TABLE "', table, '" ADD COLUMN "', nm, '" ',
                               duckdb_type_of(tab[[nm]])))
  }

  # Columns in the table that `tab` lacks -> fill with NA before appending.
  missing_in_tab <- setdiff(existing, tab_cols)
  for (nm in missing_in_tab) {
    tab[[nm]] <- NA
  }

  # Keep column order consistent with the table.
  tab <- tab[intersect(c(existing, new_cols), names(tab))]
  DBI::dbAppendTable(con, table, tab)
  nrow(tab)
}

# Map an R column to a DuckDB type for ALTER TABLE.
duckdb_type_of <- function(x) {
  if (is.factor(x)) x <- as.character(x)
  type <- switch(
    typeof(x),
    integer = "INTEGER",
    double  = "DOUBLE",
    logical = "BOOLEAN",
    character = "VARCHAR",
    "VARCHAR"
  )
  type
}
