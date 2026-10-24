#' Define a NetLogo BehaviorSpace experiment
#'
#' Thin wrapper around [logolink::create_experiment()] that also records the
#' model path and the experiment's identity. The returned object can be passed
#' directly to [run_experiment_to_duckdb()].
#'
#' @param name A single string naming the experiment (e.g. `"H6_learning_bias"`).
#' @param model Path to the NetLogo model file (`*.nlogo`, `*.nlogox`, ...).
#' @param metrics Character vector of metric reporter names to record each tick
#'   (e.g. `"avg-hunch"`, `"win-rate"`).
#' @param constants Named list of global parameter values held fixed across
#'   all sub-experiments.
#' @param sub_experiments Optional list of named lists; each element is a set
#'   of parameter values for one sub-experiment (a full factorial is expanded
#'   by NetLogo from the combinations).
#' @param repetitions Number of independent runs per sub-experiment.
#' @param time_limit Maximum number of ticks per run.
#' @param run_metrics_every_step Logical; record metrics at every tick rather
#'   than only at the end.
#' @param setup Name of the setup procedure (default `"setup"`).
#' @param go Name of the go procedure (default `"go"`).
#' @param ... Further arguments passed to [logolink::create_experiment()].
#'
#' @return An object of class `netlogo_experiment`: a list with elements
#'   `name`, `model`, `setup_file` (path to the generated XML), and `spec`
#'   (the full `create_experiment()` call for record keeping).
#' @export
#'
#' @examples
#' \dontrun{
#' xp <- define_experiment(
#'   name = "demo",
#'   model = "src/monty_hall_spatial_rev12.nlogox",
#'   metrics = c("ticks", "avg-hunch", "win-rate"),
#'   constants = list("agent-density" = 50),
#'   repetitions = 10,
#'   time_limit = 100
#' )
#' }
define_experiment <- function(name,
                              model,
                              metrics = c("ticks", "avg-hunch", "win-rate"),
                              constants = list(),
                              sub_experiments = NULL,
                              repetitions = 100L,
                              time_limit = 500L,
                              run_metrics_every_step = FALSE,
                              setup = "setup",
                              go = "go",
                              ...) {
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    stop("`name` must be a single non-empty string.", call. = FALSE)
  }
  if (!is.character(model) || length(model) != 1L) {
    stop("`model` must be a single path string.", call. = FALSE)
  }
  if (!file.exists(model)) {
    stop("model file not found: ", model, call. = FALSE)
  }
  if (!is.list(constants)) {
    stop("`constants` must be a list.", call. = FALSE)
  }

  setup_file <- tempfile(pattern = paste0("experiment-", gsub("[^A-Za-z0-9]", "_", name), "-"),
                         fileext = ".xml")

  spec <- logolink::create_experiment(
    name                = name,
    repetitions         = repetitions,
    run_metrics_every_step = run_metrics_every_step,
    time_limit          = time_limit,
    setup               = setup,
    go                  = go,
    metrics             = metrics,
    constants           = constants,
    sub_experiments     = sub_experiments,
    file                = setup_file,
    ...
  )

  structure(
    list(
      name       = name,
      model      = normalizePath(model, winslash = "/"),
      setup_file = spec,
      spec       = list(
        metrics        = metrics,
        constants      = constants,
        sub_experiments = sub_experiments,
        repetitions    = repetitions,
        time_limit     = time_limit
      )
    ),
    class = "netlogo_experiment"
  )
}

#' @export
print.netlogo_experiment <- function(x, ...) {
  cat("<netlogo_experiment>\n")
  cat("  name:        ", x$name, "\n", sep = "")
  cat("  model:       ", x$model, "\n", sep = "")
  cat("  repetitions: ", x$spec$repetitions, "\n", sep = "")
  cat("  time_limit:  ", x$spec$time_limit, "\n", sep = "")
  cat("  metrics:     ", paste(x$spec$metrics, collapse = ", "), "\n", sep = "")
  invisible(x)
}
