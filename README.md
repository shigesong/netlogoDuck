# netlogoDuck

Run [NetLogo](https://www.netlogo.org/) BehaviorSpace experiments from R and
store their results in [DuckDB](https://duckdb.org/). `netlogoDuck` connects
three parts of a simulation workflow:

1. `logolink` runs a NetLogo experiment and returns tidy results.
2. `DBI` and `duckdb` write those results to a persistent database.
3. `duckplyr` and `dplyr` query the database lazily with familiar tidyverse
   verbs.

The package can also import an existing BehaviorSpace CSV export, so it is
useful whether an experiment is launched from R or from the NetLogo interface.

## Why netlogoDuck?

BehaviorSpace can produce more data than is convenient to keep as a collection
of CSV files or load into R all at once. DuckDB provides a local, portable
database file, while duckplyr lets you analyse that data without immediately
copying the whole table into memory.

The package is deliberately focused on experiment orchestration and storage.
It does not replace NetLogo, BehaviorSpace, dplyr, or statistical modelling
packages.

## Requirements

- R >= 4.1.0
- DuckDB and the R packages `DBI`, `duckdb`, `duckplyr`, and `dplyr`
- `logolink` from GitHub for running experiments
- NetLogo >= 7.0.1 for running experiments

`NETLOGO_HOME` or `NETLOGO_CONSOLE` can be used to tell `logolink` where to
find the NetLogo installation. NetLogo is not required when only importing
existing CSV files or querying an existing DuckDB database.

## Installation

From GitHub, install the package and its GitHub-only dependency with:

```r
install.packages(c("DBI", "duckdb", "duckplyr", "dplyr", "remotes"))
remotes::install_github("danielvartan/logolink")
remotes::install_github("shigesong/netlogoDuck")
```

If you are working from a checkout of this repository, the included helper
installs missing dependencies and the local package:

```sh
Rscript install.R
```

## Basic workflow

### Define and run an experiment

`define_experiment()` creates a `netlogo_experiment` specification and a
temporary BehaviorSpace XML file. The model must already exist on disk.

```r
library(netlogoDuck)

experiment <- define_experiment(
  name = "learning_bias",
  model = "models/learning_bias.nlogox",
  metrics = c("ticks", "avg-hunch", "win-rate"),
  constants = list("agent-density" = 50),
  repetitions = 10,
  time_limit = 100
)

print(experiment)

run_experiment_to_duckdb(
  experiment = experiment,
  db_path = "results/learning_bias.duckdb",
  metadata = list(design = "baseline"),
  smoke = FALSE
)
```

Each run is appended to the results table. The package adds run-level columns
such as `run_id`, `experiment`, `model_path`, `timestamp`, `repetitions`,
`time_limit`, and `threads` to the returned rows.

For a one-call workflow, use `run_simulation()`:

```r
run_simulation(
  name = "quick_demo",
  model = "models/learning_bias.nlogox",
  db_path = "results/quick_demo.duckdb",
  metrics = c("ticks", "win-rate"),
  repetitions = 1,
  time_limit = 5,
  smoke = TRUE
)
```

`smoke = TRUE` forces one repetition and five ticks without changing the
experiment object supplied by the caller. It is intended for a quick runtime
check, not for production results.

### Import an existing BehaviorSpace CSV

NetLogo BehaviorSpace CSV exports contain metadata before their actual header.
`csv_to_duckdb()` locates the header by finding `[run number]`, skips the
metadata, and creates or replaces the destination table.

```r
csv_to_duckdb(
  input = "exports/experiment-table.csv",
  output = "results/imported.duckdb",
  table = "results"
)
```

This operation replaces the selected table; it is not an append operation.
Use `run_experiment_to_duckdb()` when repeated experiment runs should be
appended to one table.

## Query results with dplyr and duckplyr

```r
results <- read_results("results/learning_bias.duckdb")

summary <- results |>
  dplyr::filter(experiment == "learning_bias") |>
  dplyr::group_by(`agent-density`) |>
  dplyr::summarise(
    runs = dplyr::n(),
    mean_win_rate = mean(`win-rate`, na.rm = TRUE),
    .groups = "drop"
  ) |>
  dplyr::collect()

summary
```

`read_results()` returns a lazy `duckplyr_df`. `dplyr` supplies verbs such as
`filter()`, `group_by()`, and `summarise()`; duckplyr translates supported
operations into SQL; DuckDB executes the SQL. `dplyr::collect()` materializes
the final result as a local tibble.

In other words:

```text
netlogoDuck  ->  duckplyr lazy frame  ->  dplyr verbs  ->  DuckDB SQL
                                                   |
                                      dplyr::collect()
                                                   v
                                           local tibble
```

The write path does not use dplyr. `netlogoDuck` writes through DBI and DuckDB;
dplyr and duckplyr are used for the analysis/read path. See the vignette for a
more detailed explanation:

```r
vignette("querying-results", package = "netlogoDuck")
```

### Collect immediately

For a small table, or when a local data frame is required, set `collect = TRUE`:

```r
local_results <- read_results(
  "results/learning_bias.duckdb",
  collect = TRUE
)
```

This reads the result into R memory, so use it deliberately for large
BehaviorSpace sweeps.

### Use raw SQL when appropriate

The database is an ordinary DuckDB file and can be queried directly:

```r
con <- db_open("results/learning_bias.duckdb", read_only = TRUE)

DBI::dbGetQuery(
  con,
  'SELECT experiment, COUNT(*) AS n
     FROM "results"
    GROUP BY experiment'
)

db_close(con)
```

## Data flow and ownership

| Component | Responsibility |
| --- | --- |
| `netlogoDuck` | Define experiments, run/import results, append rows, and expose readers |
| `logolink` | Generate/run the BehaviorSpace experiment and return results |
| `DBI` + `duckdb` | Connect to the database and store/execute data |
| `duckplyr` | Represent DuckDB tables as lazy data frames and push operations down |
| `dplyr` | Provide the analysis verbs and `collect()` |

This separation means that a NetLogo experiment can be run once and then
analysed repeatedly without rerunning the simulation.

## Important behavior and limitations

- `csv_to_duckdb()` replaces its destination table.
- `run_experiment_to_duckdb()` appends results and widens the table when later
  runs introduce new metadata columns.
- A later result that omits an existing column receives `NA` for that column.
- BehaviorSpace metric names often contain hyphens or other non-syntactic
  characters. Refer to them with backticks in dplyr expressions, for example
  `` `win-rate` ``.
- A lazy `duckplyr_df` is attached to duckplyr's DuckDB connection for the R
  session. Call `dplyr::collect()` when a local result is needed.
- Unsupported duckplyr operations may fall back to local dplyr evaluation. For
  large tables, prefer operations that can be pushed into DuckDB.
- NetLogo execution failures raise an error by default, so they cannot be
  confused with valid empty results. Set `quiet_fail = TRUE` only when a
  pipeline intentionally wants a warning and zero-row return.
- The package does not include NetLogo models or a NetLogo runtime.
- Actual experiment execution may be long-running and writes to the specified
  database. Use `smoke = TRUE` for a deliberate quick validation.

## Development and testing

Run the package check from the repository directory:

```sh
R CMD check .
```

Run the test suite directly with:

```sh
Rscript -e 'testthat::test_dir("tests/testthat")'
```

Tests that require an external NetLogo model are skipped when the fixture is
not available. Ordinary ingestion and query tests use temporary CSV and DuckDB
files and do not launch NetLogo.

## Further documentation

- Vignette: `vignette("querying-results", package = "netlogoDuck")`
- Package reference: `?netlogoDuck`
- Experiment definition: `?define_experiment`
- Experiment execution: `?run_experiment_to_duckdb`
- CSV ingestion: `?csv_to_duckdb`
- Lazy querying: `?read_results`
- Connection helpers: `?db_open`

## License

GPL-3. See `LICENSE` for the full license text.
 
