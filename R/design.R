#' Build a Latin hypercube design on the model's own ranges
#'
#' Draws a maximin Latin hypercube with [lhs::maximinLHS()], maps each column
#' onto the range of the factor it belongs to, rounds to the model's integer
#' grid, allocates categorical factors in balanced blocks, and appends settings
#' that do not vary. The result is one row per design point, so it is a row-wise
#' design and not a grid: no two rows are crossed.
#'
#' Three kinds of variable are handled differently. Numeric factors are sampled
#' through `ranges`. Categorical factors with several levels are allocated
#' through `levels` so that every level appears equally often. Settings that
#' never vary, including single-level factors, go in `fixed`.
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
#' @param levels Named list of categorical factors, each a vector of two or more
#'   distinct levels (e.g. `list(scenario = c("baseline", "policy-a"))`). Each
#'   level is allocated once per block of rows, so counts differ by at most one.
#'   Make `n` a multiple of the number of levels for exact balance. Levels are
#'   allocated independently of the numeric strata: every level sees a
#'   representative share of the numeric space, not all of it. To cross a level
#'   with the whole numeric design instead, leave it out of `levels` and pass it
#'   in `constants` to [define_experiment()], which multiplies the run count.
#' @param seed Optional single number; when supplied, the draw is reproducible.
#' @param dup Number of candidate points `maximinLHS()` weighs per design
#'   point; larger values spread the design further apart at some cost in
#'   running time.
#'
#' @return A [tibble][tibble::tibble-package] with `n` rows: one column per
#'   element of `ranges` (rounded to integers), then one column per element of
#'   `levels`, then one column per element of `fixed`.
#' @export
#'
#' @seealso [define_experiment()] to turn the rows into an experiment.
#'
#' @examples
#' design <- lhs_design(
#'   n = 12,
#'   ranges = list(
#'     "wolf-reproduce"      = c(1, 20),
#'     "grass-regrowth-time" = c(5, 100)
#'   ),
#'   levels = list(scenario = c("baseline", "policy-a", "policy-b")),
#'   fixed = list("model-version" = "sheep-wolves-grass"),
#'   seed = 2026
#' )
#' design
#'
#' # Three levels over twelve rows: four points each.
#' table(design[["scenario"]])
lhs_design <- function(n,
                       ranges,
                       fixed = list(),
                       levels = list(),
                       seed = NULL,
                       dup = 5L) {
  if (!is_positive_integerish(n)) {
    stop("`n` must be one positive integer.", call. = FALSE)
  }
  validate_ranges(ranges)
  validate_named_list(fixed, "fixed")
  validate_levels(levels)
  clash <- intersect(names(levels), c(names(ranges), names(fixed)))
  if (length(clash) > 0L) {
    stop("`levels` must not repeat a name used in `ranges` or `fixed`: ",
         paste(clash, collapse = ", "), call. = FALSE)
  }
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

  # Categorical factors are not sampled on a continuum: each block of rows gets
  # every level once, in random order, which is the categorical analogue of one
  # point per stratum.
  for (factor_name in names(levels)) {
    values <- as.character(levels[[factor_name]])
    if (n %% length(values) != 0L) {
      warning("`n` (", n, ") is not a multiple of the ", length(values),
              " levels of `", factor_name, "`: the last block is partial.",
              call. = FALSE)
    }
    design[[factor_name]] <- allocate_levels(values, n)
  }

  if (length(fixed) > 0L) {
    design[names(fixed)] <- fixed
  }
  design
}

# Give every block of `length(values)` consecutive rows all the levels, in
# random order. A final short block takes a random subset of the levels.
allocate_levels <- function(values, n) {
  size <- length(values)
  out <- character(n)
  for (start in seq(1L, n, by = size)) {
    index <- start:min(start + size - 1L, n)
    out[index] <- sample(values, length(index))
  }
  out
}
