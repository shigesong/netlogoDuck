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

test_that("define_experiment validates experiment parameters", {
  model <- tempfile(fileext = ".nlogox")
  writeLines("placeholder", model)

  expect_error(
    netlogoDuck::define_experiment("x", model, metrics = character()),
    "metrics"
  )
  expect_error(
    netlogoDuck::define_experiment("x", model, repetitions = 0),
    "repetitions"
  )
  expect_error(
    netlogoDuck::define_experiment("x", model, time_limit = -1),
    "time_limit"
  )
  expect_error(
    netlogoDuck::define_experiment("x", model, run_metrics_every_step = NA),
    "run_metrics_every_step"
  )
  expect_error(
    netlogoDuck::define_experiment("x", model, constants = setNames(list(1), "")),
    "constants"
  )
})

test_that("bind_metadata stamps flat scalar columns", {
  tab <- data.frame(x = 1:3)
  out <- netlogoDuck:::bind_metadata(tab, list(run_id = "r1", design = "H6"))
  expect_equal(out$run_id, rep("r1", 3))
  expect_equal(out$design, rep("H6", 3))
})

test_that("run IDs are unique for rapid successive calls", {
  ids <- replicate(100L, netlogoDuck:::new_run_id("experiment"))

  expect_length(unique(ids), 100L)
  expect_true(all(startsWith(ids, "experiment-")))
})

test_that("run_experiment_to_duckdb validates execution arguments", {
  xp <- structure(list(), class = "netlogo_experiment")
  db <- tempfile(fileext = ".duckdb")

  expect_error(
    netlogoDuck::run_experiment_to_duckdb(xp, db, threads = 0),
    "threads"
  )
  expect_error(
    netlogoDuck::run_experiment_to_duckdb(xp, db, timeout = -1),
    "timeout"
  )
  expect_error(
    netlogoDuck::run_experiment_to_duckdb(xp, db, metadata = list("not named")),
    "metadata"
  )
  expect_error(
    netlogoDuck::run_experiment_to_duckdb(xp, db, smoke = NA),
    "smoke"
  )
  expect_error(
    netlogoDuck::run_experiment_to_duckdb(xp, db, quiet_fail = NA),
    "quiet_fail"
  )
})

test_that("NetLogo execution failures are errors by default", {
  xp <- structure(
    list(
      name = "demo",
      model = "demo.nlogox",
      setup_file = "demo.xml",
      spec = list(repetitions = 1L, time_limit = 5L)
    ),
    class = "netlogo_experiment"
  )
  db <- tempfile(fileext = ".duckdb")

  testthat::with_mocked_bindings(
    expect_error(
      netlogoDuck::run_experiment_to_duckdb(xp, db),
      "demo.*NetLogo experiment failed.*simulated failure"
    ),
    run_experiment = function(...) stop("simulated failure"),
    .package = "logolink"
  )
})

test_that("smoke mode forces one repetition and five ticks", {
  model <- tempfile(fileext = ".nlogox")
  writeLines("placeholder", model)
  xp <- structure(
    list(
      name = "demo",
      model = model,
      setup_file = "original.xml",
      spec = list(
        metrics = "ticks",
        constants = list(),
        sub_experiments = NULL,
        repetitions = 99L,
        time_limit = 500L
      )
    ),
    class = "netlogo_experiment"
  )
  db <- tempfile(fileext = ".duckdb")
  create_args <- list()
  run_args <- list()

  testthat::with_mocked_bindings(
    {
      n <- netlogoDuck::run_experiment_to_duckdb(xp, db, smoke = TRUE)

      expect_equal(n, 1L)
      expect_equal(create_args[[1L]]$repetitions, 1L)
      expect_equal(create_args[[1L]]$time_limit, 5L)
      expect_false(create_args[[1L]]$run_metrics_every_step)
      expect_equal(run_args[[1L]]$setup_file, "smoke.xml")
      expect_equal(xp$spec$repetitions, 99L)
      expect_equal(xp$spec$time_limit, 500L)
    },
    create_experiment = function(...) {
      create_args <<- c(create_args, list(list(...)))
      "smoke.xml"
    },
    run_experiment = function(...) {
      run_args <<- c(run_args, list(list(...)))
      list(table = data.frame(ticks = 5L))
    },
    .package = "logolink"
  )
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
