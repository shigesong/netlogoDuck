#' Build a Latin hypercube design on the model's own ranges
#'
#' Draws a maximin Latin hypercube with [lhs::maximinLHS()], maps each column
#' onto the range of the factor it belongs to, rounds to the model's integer
#' grid, and appends settings that do not vary. The result is one row per design
#' point, so it is a row-wise design and not a grid: no two rows are crossed.
#'
#' Pass the rows to [define_experiment()] as `sub_experiments`; a data frame row
#' becomes a sub-experiment with `as.list()`, and the column names must match
#' NetLogo global names exactly.
#'
#' @param n Number of design points.
#' @param ranges Named list of length-2 numeric vectors, one per factor, giving
#'   `c(low, high)` in the model's own units. Column order follows list order.
#' @param fixed Named list of settings held constant across every design point
#'   (e.g. `list("model-version" = "sheep-wolves-grass")`). Appended as
#'   columns to the returned design.
#' @param seed Optional single number; when supplied, the draw is reproducible.
#' @param dup Number of candidate points `maximinLHS()` weighs per design
#'   point; larger values spread the design further apart at some cost in
#'   running time.
#'
#' @return A [tibble][tibble::tibble-package] with `n` rows: one column per
#'   element of `ranges` (rounded to integers) followed by one column per
#'   element of `fixed`.
#' @export
#'
#' @seealso [define_experiment()] to turn the rows into an experiment.
#'
#' @examples
#' design <- lhs_design(
#'   n = 10,
#'   ranges = list(
#'     "wolf-reproduce"      = c(1, 20),
#'     "grass-regrowth-time" = c(5, 100)
#'   ),
#'   fixed = list("model-version" = "sheep-wolves-grass"),
#'   seed = 2026
#' )
#' design
lhs_design <- function(n,
                       ranges,
                       fixed = list(),
                       seed = NULL,
                       dup = 5L) {
  if (!is_positive_integerish(n)) {
    stop("`n` must be one positive integer.", call. = FALSE)
  }
  validate_ranges(ranges)
  validate_named_list(fixed, "fixed")
  if (!is.null(seed)) {
    if (!is.numeric(seed) || length(seed) != 1L || is.na(seed)) {
      stop("`seed` must be NULL or a single number.", call. = FALSE)
    }
  }
  if (!is_positive_integerish(dup)) {
    stop("`dup` must be one positive integer.", call. = FALSE)
  }

  if (!is.null(seed)) set.seed(seed)

  unit <- lhs::maximinLHS(n, length(ranges), dup = dup)

  # Unit values are scaled column by column: `each = n` recycles the k ranges
  # down the n rows, so no loop over factors is needed.
  low <- vapply(ranges, function(range) range[[1]], numeric(1))
  high <- vapply(ranges, function(range) range[[2]], numeric(1))
  scaled <- unit * rep(high - low, each = n) + rep(low, each = n)

  design <- tibble::as_tibble(round(scaled), .name_repair = "minimal")
  names(design) <- names(ranges)
  if (length(fixed) > 0L) {
    design[names(fixed)] <- fixed
  }
  design
}
