# 01 — Working Conventions

- Branches: orchestrator/setup branches `devin/<unix-ts>-<slug>`; fan-out child branches `migrate/<pipeline>/<wave>-<unit>`. All PR into the run branch `migration-run-9`. Never into `main`.
- Write targets: children write only to the UC namespace in their brief (declared in the wave manifest, always inside `migration_demo`) and never edit `.migration/`; the orchestrator is the single writer of wave results. `.migration/allowed_targets.json` is the allow-list.
- PR-evidence contract: every unit PR carries its own recon output (row counts, aggregates, EXCEPT diffs vs `redshift_src`) in the PR description.
- Converted code lives under `databricks/` mirroring `sql/` layout (`databricks/etl/`, `databricks/reports/`); legacy `sql/` is read-only during migration.
- Numeric order execution preserved: ETL 10 before 11; 12 is the orchestration wrapper.
- Execution helpers: `~/dbx_sql.py` (Statement Execution API, warehouse `565cd2fd713738c4`), `~/rs_sql.py` (Redshift Data API). Redshift mart rebuilds only as `demoadmin`, then `GRANT SELECT ON ALL TABLES IN SCHEMA mart TO PUBLIC`.
- Secrets referenced by name only; never committed or printed.
- PR content: no user-identifying information (multi-tenant demo account).
- Stops: `stop_mode` per `00_context.md` (soft: 60-second window then recommended default; STOP E always hard). Every stop writes one `06_decisions.md` row with provenance `user:<id>` or `default-accepted (soft, 60s, no reply)`.
- Message style: 2-4 sentences, one decision, recommended answer + exact approving reply, artifacts attached; events limited to STOPs A/B/C/E, wave close (D), halts.
