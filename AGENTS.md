# netlogoDuck

## What this is

- This directory is a standalone R package that runs NetLogo BehaviorSpace experiments through `logolink`, stores results in DuckDB, and reads them with `duckplyr`; it is not a runnable NetLogo model repository.
- Public API code is in `R/`: connection helpers in `connect.R`, experiment definition in `experiment.R`, CSV ingestion in `ingest.R`, lazy queries in `query.R`, and experiment execution/append logic in `run.R`.
- NetLogo model files are external inputs. `define_experiment()` validates the model path, and `run_experiment_to_duckdb()` delegates execution to `logolink`; do not assume a model or NetLogo runtime is present here.

## Development and verification

- Required runtime is R >= 4.1 with the packages listed in `DESCRIPTION` (`DBI`, `duckdb`, `duckplyr`, `dplyr`, `logolink`); `testthat` and `withr` are suggested dependencies.
- `Rscript install.R` installs missing CRAN dependencies, installs `logolink` from GitHub (`danielvartan/logolink`, not on CRAN), and installs this package. NetLogo >= 7.0.1 is required at run time; `NETLOGO_HOME` or `NETLOGO_CONSOLE` overrides console discovery.
- Run the package check from this directory with `R CMD check .`; this is the broadest repository-defined verification command.
- Run a focused test file with `Rscript -e 'testthat::test_file("tests/testthat/test-ingest.R")'` (replace the path as needed), or all tests with `Rscript -e 'testthat::test_dir("tests/testthat")'`. The package must be installed/available to R because the tests load `netlogoDuck`.
- The experiment-definition test skips when its external `src/monty_hall_spatial_rev12.nlogox` fixture is unavailable; the test suite does not substitute for a real NetLogo experiment run.
- Do not run package scripts or simulations casually: `run_experiment_to_duckdb()` can launch long headless NetLogo jobs and writes/extends `.duckdb` files. Prefer `smoke = TRUE` for a deliberate quick validation.

## Source of truth and generated files

- Edit roxygen comments and R source, not `NAMESPACE` or files under `man/`; those are generated from the package documentation. Regenerate them with roxygen2 when making API/documentation changes.
- `data-raw/parameter_groups.R` regenerates both packaged datasets and must be run from this directory (`Rscript data-raw/parameter_groups.R`); it uses `usethis::use_data()` and can overwrite `data/*.rda`.
- Keep database outputs, experiment outputs, and model files outside the package unless they are intentionally test fixtures; `.Rbuildignore` already excludes common local output and workspace directories.

## Data flow invariants

- `csv_to_duckdb()` detects the BehaviorSpace header by finding `[run number]`, skips preceding metadata, and replaces the destination table; it is not an append operation.
- `run_experiment_to_duckdb()` appends rows and widens an existing DuckDB table for new metadata columns, filling columns absent from a later result with `NA`. Reuse one `db_con` when multiple operations should share an open connection; otherwise helpers open and close their own connection.
