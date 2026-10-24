#' Conceptual grouping of the monty_hall_spatial_rev13 model parameters
#'
#' A data frame classifying the six interface parameters of
#' `src/monty_hall_spatial_rev13.nlogox` into three functional modules of the
#' model's causal loop (population -> observe -> learn -> transmit -> adapt).
#'
#' @format A data frame with 6 rows and 5 columns:
#' \describe{
#'   \item{parameter}{Name of the NetLogo parameter (matches the variable name).}
#'   \item{group}{Short machine-readable group id.}
#'   \item{group_label}{Human-readable group label.}
#'   \item{widget}{NetLogo interface widget type: `slider`, `chooser`, or `switch`.}
#'   \item{description}{One-line conceptual description of the parameter's role.}
#' }
#'
#' The three groups are:
#' \describe{
#'   \item{population_spatial}{Who exists and who can see whom (environment).}
#'   \item{learning_rule}{How observation becomes a strategy choice (cognition).}
#'   \item{transmission}{How a winner teaches an accepted learner (communication).}
#' }
#'
#' @source Derived from the interface widgets in
#'   `src/monty_hall_spatial_rev13.nlogox`.
#' @seealso [run_experiment_to_duckdb()], [read_results()]
#'
#' @examples
#' parameter_groups
"parameter_groups"
