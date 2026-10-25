library(testthat)

test_that("find_header_line skips NetLogo metadata", {
  f <- tempfile(fileext = ".csv")
  writeLines(c(
    '"BehaviorSpace results (NetLogo 7.0.4)","Table version 2.0"',
    '"/path/model.nlogox"',
    '""',
    '"08/11/2026 19:47:44:190 -0400"',
    '"min-pxcor","max-pxcor"',
    '"-16","16"',
    '"[run number]","accept-prob","ticks","avg-hunch"',
    '"1","50","0","49.5"'
  ), f)

  expect_equal(netlogoDuck:::find_header_line(f), 6L)

  # No header row -> error
  g <- tempfile(fileext = ".csv")
  writeLines(c("a,b", "1,2"), g)
  expect_error(netlogoDuck:::find_header_line(g), "no header row")
})

test_that("csv_to_duckdb imports a NetLogo CSV and types run number", {
  f <- tempfile(fileext = ".csv")
  writeLines(c(
    '"BehaviorSpace results (NetLogo 7.0.4)","Table version 2.0"',
    '"/path/model.nlogox"',
    '""',
    '"08/11/2026 19:47:44:190 -0400"',
    '"min-pxcor","max-pxcor"',
    '"-16","16"',
    '"[run number]","accept-prob","ticks","avg-hunch"',
    '"1","50","0","49.5"',
    '"2","25","0","48.1"'
  ), f)
  out <- tempfile(fileext = ".duckdb")

  n <- netlogoDuck::csv_to_duckdb(f, out, table = "res", quiet = TRUE)
  expect_equal(n, 2L)

  con <- netlogoDuck::db_open(out)
  on.exit(netlogoDuck::db_close(con))
  expect_true(DBI::dbExistsTable(con, "res"))
  expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) FROM res")[[1]], 2)
  typ <- DBI::dbGetQuery(con, "SELECT typeof(\"[run number]\") AS t FROM res LIMIT 1")[[1]]
  expect_equal(typ, "INTEGER")
})

test_that("db_open / db_close round-trip a file", {
  out <- tempfile(fileext = ".duckdb")
  con <- netlogoDuck::db_open(out)
  expect_s4_class(con, "duckdb_connection")
  netlogoDuck::db_close(con)
  expect_true(file.exists(out))
})

test_that("public connection and query arguments are validated", {
  expect_error(netlogoDuck::db_open(character()), "db_path")
  expect_error(netlogoDuck::db_open(tempfile(), read_only = NA), "read_only")
  out <- tempfile(fileext = ".duckdb")
  con <- netlogoDuck::db_open(out)
  netlogoDuck::db_close(con)
  expect_error(netlogoDuck::read_results(out, collect = NA), "collect")
})

test_that("read_results returns a lazy duckplyr frame", {
  f <- tempfile(fileext = ".csv")
  writeLines(c(
    '"[run number]","accept-prob","ticks","avg-hunch"',
    '"1","50","0","49.5"'
  ), f)
  out <- tempfile(fileext = ".duckdb")
  netlogoDuck::csv_to_duckdb(f, out, quiet = TRUE)

  df <- netlogoDuck::read_results(out)
  expect_true(inherits(df, "duckplyr_df"))
  expect_equal(nrow(dplyr::collect(dplyr::count(df))), 1L)

  local <- netlogoDuck::read_results(out, collect = TRUE)
  expect_true(inherits(local, "data.frame"))
})
