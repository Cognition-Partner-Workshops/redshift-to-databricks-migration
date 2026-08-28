# 01 — Working Conventions

- Branches: unit branches `devin/<unix-ts>-<slug>` PR into the run branch `migration-run-6`. Never into `main`.
- PR-evidence contract: every unit PR carries its own recon output (row counts, aggregates, EXCEPT diffs vs `redshift_src`) in the PR description.
- Converted code lives under `databricks/` mirroring `sql/` layout (`databricks/etl/`, `databricks/reports/`); legacy `sql/` is read-only during migration.
- Numeric order execution preserved: ETL 10 before 11; 12 is the orchestration wrapper.
- Execution helpers: `~/dbx_sql.py` (Statement Execution API, warehouse `565cd2fd713738c4`), `~/rs_sql.py` (Redshift Data API). Redshift mart rebuilds only as `demoadmin`, then `GRANT SELECT ON ALL TABLES IN SCHEMA mart TO PUBLIC`.
- Secrets referenced by name only; never committed or printed.
- PR content: no user-identifying information (multi-tenant demo account).
