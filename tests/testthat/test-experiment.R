library(testthat)

test_that("define_experiment produces a netlogo_experiment", {
  model <- file.path("..", "..", "..", "src", "monty_hall_spatial_rev12.nlogox")
  if (!file.exists(model)) {
    skip(paste("model not found:", model))
  }

  xp <- netlogoDuck::define_experiment(
    name = "unit_test",
    model = model,
    metrics = c("ticks", "avg-hunch"),
    constants = list("agent-density" = 50),
    repetitions = 2L,
    time_limit = 10L
  )
  expect_s3_class(xp, "netlogo_experiment")
  expect_equal(xp$name, "unit_test")
  expect_true(file.exists(xp$setup_file))
  expect_match(xp$model, "\\.nlogox$")

  # The XML should be loadable by logolink's inspector.
  expect_no_error(logolink::inspect_experiment(xp$setup_file))
})

test_that("define_experiment validates inputs", {
  expect_error(netlogoDuck::define_experiment("x", "/nonexistent.nlogox"),
               "model file not found")
  expect_error(netlogoDuck::define_experiment("", "src/monty_hall_spatial_rev12.nlogox"),
               "name")
})

test_that("bind_metadata stamps flat scalar columns", {
  tab <- data.frame(x = 1:3)
  out <- netlogoDuck:::bind_metadata(tab, list(run_id = "r1", design = "H6"))
  expect_equal(out$run_id, rep("r1", 3))
  expect_equal(out$design, rep("H6", 3))
})

test_that("append_to_duckdb creates then appends", {
  out <- tempfile(fileext = ".duckdb")
  con <- netlogoDuck::db_open(out)
  on.exit(netlogoDuck::db_close(con))

  netlogoDuck:::append_to_duckdb(con, data.frame(a = 1:3, b = letters[1:3]), "t")
  netlogoDuck:::append_to_duckdb(con, data.frame(a = 4:5, b = c("d", "e")), "t")
  expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) FROM t")[[1]], 5L)
})

test_that("append_to_duckdb widens the table for new columns", {
  out <- tempfile(fileext = ".duckdb")
  con <- netlogoDuck::db_open(out)
  on.exit(netlogoDuck::db_close(con))

  netlogoDuck:::append_to_duckdb(con, data.frame(a = 1:3), "t")
  netlogoDuck:::append_to_duckdb(con, data.frame(a = 4:5, design = "H6"), "t")
  expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) FROM t")[[1]], 5L)
  expect_equal(DBI::dbListFields(con, "t"), c("a", "design"))
  expect_true(all(is.na(DBI::dbGetQuery(con, "SELECT design FROM t WHERE a < 4")$design)))
})

test_that("append_to_duckdb fills missing columns from existing table", {
  out <- tempfile(fileext = ".duckdb")
  con <- netlogoDuck::db_open(out)
  on.exit(netlogoDuck::db_close(con))

  netlogoDuck:::append_to_duckdb(con, data.frame(a = 1:3, design = "H6"), "t")
  netlogoDuck:::append_to_duckdb(con, data.frame(a = 4:5), "t")
  expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) FROM t")[[1]], 5L)
  res <- DBI::dbGetQuery(con, "SELECT design FROM t WHERE a = 4")
  expect_true(is.na(res$design))
})
