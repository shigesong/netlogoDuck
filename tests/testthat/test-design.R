test_that("lhs_design returns one rounded row per design point", {
  ranges <- list(
    "wolf-reproduce"      = c(1, 20),
    "grass-regrowth-time" = c(5, 100)
  )
  design <- netlogoDuck::lhs_design(n = 12, ranges = ranges, seed = 2026)

  expect_s3_class(design, "tbl_df")
  expect_equal(nrow(design), 12)
  expect_equal(names(design), names(ranges))
  expect_true(all(vapply(design, is.numeric, logical(1))))

  # Every value must sit inside its range and on the integer grid.
  for (factor in names(ranges)) {
    range <- ranges[[factor]]
    expect_true(all(design[[factor]] >= range[1]))
    expect_true(all(design[[factor]] <= range[2]))
    expect_equal(design[[factor]], round(design[[factor]]))
  }
})

test_that("lhs_design appends fixed settings to every row", {
  design <- netlogoDuck::lhs_design(
    n = 6,
    ranges = list("density" = c(40, 80)),
    fixed = list("model-version" = "sheep-wolves-grass", "show-energy?" = FALSE),
    seed = 1
  )

  expect_equal(
    names(design),
    c("density", "model-version", "show-energy?")
  )
  expect_equal(rep("sheep-wolves-grass", 6), design[["model-version"]])
  expect_equal(rep(FALSE, 6), design[["show-energy?"]])
})

test_that("lhs_design is reproducible only when a seed is given", {
  ranges <- list("density" = c(40, 80), "tolerance" = c(20, 100))
  first  <- netlogoDuck::lhs_design(8, ranges, seed = 42)
  second <- netlogoDuck::lhs_design(8, ranges, seed = 42)

  expect_identical(first, second)
})

test_that("lhs_design rows convert to sub-experiment lists", {
  design <- netlogoDuck::lhs_design(
    n = 4,
    ranges = list(density = c(40, 80)),
    fixed = list("%-similar-wanted" = 30),
    seed = 7
  )
  rows <- lapply(seq_len(nrow(design)), function(i) as.list(design[i, , drop = FALSE]))

  expect_length(rows, 4)
  expect_named(rows[[1]], c("density", "%-similar-wanted"))
  expect_length(rows[[1]][["density"]], 1L)
})

test_that("lhs_design validates its inputs", {
  ranges <- list(density = c(40, 80))

  expect_error(netlogoDuck::lhs_design(0, ranges), "`n`")
  expect_error(netlogoDuck::lhs_design(5, list(c(1, 2))), "ranges")
  expect_error(netlogoDuck::lhs_design(5, list()), "at least one factor")
  expect_error(netlogoDuck::lhs_design(5, list(density = c(80, 40))), "low < high")
  expect_error(netlogoDuck::lhs_design(5, list(density = c(40, 80, 90))), "low < high")
  expect_error(netlogoDuck::lhs_design(5, list(density = "a")), "low < high")
  expect_error(netlogoDuck::lhs_design(5, ranges, fixed = list(1)), "`fixed`")
  expect_error(netlogoDuck::lhs_design(5, ranges, seed = c(1, 2)), "`seed`")
  expect_error(netlogoDuck::lhs_design(5, ranges, dup = 0), "`dup`")
})
