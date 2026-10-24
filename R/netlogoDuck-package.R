#' netlogoDuck: Run NetLogo BehaviorSpace Experiments into DuckDB
#'
#' Tools to define and run NetLogo BehaviorSpace experiments through
#' [logolink::run_experiment()], append their results to DuckDB, import
#' existing BehaviorSpace CSV exports, and query results lazily with
#' `duckplyr`.
#'
#' @section Main workflow:
#' 1. Define an experiment with [define_experiment()].
#' 2. Run it with [run_experiment_to_duckdb()] or [run_simulation()].
#' 3. Query the database with [read_results()].
#'
#' Use [csv_to_duckdb()] to import results that were exported directly from
#' NetLogo instead of run through this package.
#'
#' @keywords internal
#' @aliases netlogoDuck
"_PACKAGE"
