# Run 2 migration context

- Source: local Docker Trino 483, reachable from this VM only.
- `lake` is the Hive/Parquet catalog; `ops` is the PostgreSQL JDBC catalog.
- Target: Databricks through secret names `DATABRICKS_DEMO_HOST` and `DATABRICKS_DEMO_TOKEN`.
- Warehouse: `565cd2fd713738c4`.
- Migration catalog: `trino_migration_demo`.
- Schemas: `trino_src` (run-1 Trino snapshot landing), `core`, `ops`, and `mart`.
- Dialect skill: `skills/trino`.
- `marts`: `--mode snapshot --family databricks`; source side is the run-1
  `trino_src.*` snapshot because `recon.adapters.SOURCE_ADAPTERS` has no
  `trino` source adapter. This is DEGRADED: it proves against snapshot rows,
  not a live Trino reread.
- `ops_tables`: `--mode live --family postgres`; source is the local
  PostgreSQL behind the `ops` catalog, using secret name `TRINO_OPS_DSN`.
- `stop_mode: hard`.

## Glossary

- **DEGRADED**: evidence is valid for its stated snapshot or source route but
  does not prove a live reread of the unavailable source adapter.
- **Source**: the read-only Trino estate and its PostgreSQL operational catalog.
- **Target**: the designated `trino_migration_demo` Databricks catalog.
- **Harness**: the `dbx-recon` reconciliation tool; its result is merge
  authority.
