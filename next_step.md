# Next steps for netlogoDuck

`netlogoDuck` already has a useful core workflow:

1. Define or run a NetLogo BehaviorSpace experiment.
2. Store results in DuckDB.
3. Read results lazily through duckplyr.
4. Analyse them with dplyr syntax.

The recommended improvements are staged below. Make experiment runs reliable
and auditable before adding higher-level analysis features.

## Phase 1: correctness and usability

### Improve the README

Expand `README.md` with the problem the package solves, installation and
requirements, a minimal end-to-end example, the relationship between
`netlogoDuck`, `DBI`, `duckdb`, `duckplyr`, and `dplyr`, links to the vignettes,
and limitations such as NetLogo being an external runtime.

### Strengthen input validation

Validate public arguments explicitly:

- `threads` is one positive integer;
- `timeout` is non-negative or `Inf`;
- `repetitions` is a positive integer;
- `time_limit` is a non-negative integer;
- table and schema names are valid or safely quoted;
- metadata is a named list with supported values;
- database connections are open DuckDB connections;
- output types are supported by `logolink`.

### Make run IDs reliably unique

The current second-level timestamp can collide when two runs of the same
experiment happen within one second. Replace it with a UUID, a timestamp with
sub-second precision, or a timestamp plus a random suffix.

### Improve failure handling

Do not make a failed NetLogo run look like a successful zero-row run by
default. Prefer rethrowing the error with context, or add an explicit
`quiet_fail = FALSE` option for workflows that intentionally tolerate failure.

### Add tests

Cover unique run IDs, argument validation, failure behavior, and the smoke-run
path.

## Phase 2: database reliability

### Handle type changes explicitly

The append logic widens tables for new columns but does not define a policy for
incompatible types in existing columns. Compare incoming and existing DuckDB
types and choose an explicit policy:

1. strict failure with a clear diagnostic;
2. coercion to the existing type; or
3. safe type promotion.

Strict behavior should be the default.

### Centralize identifier quoting

Create one internal helper for safely quoting table, schema, and column names.
Use it consistently in all generated SQL. Keep identifier quoting separate
from value parameterization.

### Add schema support

Allow result tables to be stored and read from named DuckDB schemas. This will
help separate raw results, run metadata, summaries, and diagnostics within one
database file.

### Add database inspection helpers

Useful small helpers include:

```r
list_result_tables(db_path)
result_columns(db_path, table = "results")
result_runs(db_path, table = "results")
result_summary(db_path, table = "results")
```

They should return ordinary tibbles and use DBI internally.

### Test database edge cases

Test spaces, hyphens, and quotes in identifiers; type conflicts; factor, Date,
POSIXct, logical, integer, and double columns; missing and newly introduced
columns; and malformed or empty input files.

## Phase 3: reproducibility and provenance

Record enough information to reproduce and audit each run:

- package versions;
- DuckDB and NetLogo versions;
- operating system;
- model path and model file hash;
- experiment specification;
- constants and subexperiments;
- random seed, when supported;
- execution start and end times;
- execution status and error message.

Add a helper such as:

```r
run_metadata(db_path)
```

### Consider normalized run metadata

Currently run metadata is copied onto every result row. A more scalable design
would use a results table keyed by `run_id` and a separate runs table containing
the experiment, model hash, timestamp, parameters, status, and error message.

Keep the existing flat-table behavior for compatibility; introduce normalized
storage later as an explicit mode.

## Phase 4: improve the experiment API

### Add a print method

Implement `print.netlogo_experiment()` to show the model, metrics, constants,
repetitions, time limit, and setup procedures.

### Add experiment validation

Provide:

```r
validate_experiment(xp)
```

It should check the model, generated XML, required procedures, metrics, and
experiment parameters.

### Add a dry-run mode

Provide a mode that validates the model, generates the BehaviorSpace setup,
shows the planned command, and does not run NetLogo or modify the database.
This is distinct from `smoke = TRUE`, which executes a quick validation run.

### Support explicit seeds

If supported by `logolink`, expose a seed argument for reproducible replicated
experiments.

## Phase 5: querying and interoperability

Add these only after storage and provenance are reliable.

### Query helpers

Consider a `read_runs(db_path)` helper and narrowly scoped helpers for common
run filtering or summaries. Keep statistical modeling in dplyr, tidymodels,
and domain-specific packages rather than turning `netlogoDuck` into a general
statistics package.

### Export helpers

Consider:

```r
export_results(db_path, output = "results.parquet")
```

Useful targets include Parquet, CSV, and local tibbles. Parquet is especially
valuable for interoperability with Python, Julia, and command-line DuckDB.

## Release readiness

Before substantially expanding the API:

- add `NEWS.md`;
- configure GitHub Actions for `R CMD check` and tests;
- add pkgdown documentation;
- ensure examples and vignettes do not require a local NetLogo installation;
- keep NetLogo-dependent integration tests explicitly opt-in;
- document versioning and compatibility expectations.

## Recommended next milestone

The highest-value next milestone is:

> Make every experiment run an auditable, uniquely identified database record.

Combine reliable run IDs, explicit status and failure metadata, model hashes,
experiment specifications, stronger append/type validation, and focused tests.
This improves scientific reproducibility and data safety without expanding the
package into a general statistical framework.
