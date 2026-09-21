# Trino estate on Databricks

Converted from `trino/sql`. Target catalog `trino_migration_demo` (schemas `trino_src`, `core`, `ops`, `mart`),
run on the existing SQL warehouse. Assessment: `docs/ASSESSMENT.md`. Evidence: `docs/evidence/`. Recon: `recon/trino/`.

Run order (`python3 databricks/run_sql.py <files...>`, needs `DATABRICKS_DEMO_HOST` / `DATABRICKS_DEMO_TOKEN`):

1. `ddl/01_schemas.sql` .. `ddl/05_trino_src_tables.sql`
2. Export from Trino and upload:
   `sh docs/evidence/before/export.sh` then
   `databricks fs cp -r export/csv dbfs:/Volumes/trino_migration_demo/trino_src/landing/csv`
3. `landing/00_load_trino_src.sql` (CSV -> `trino_src`), `landing/01_load_core_ops.sql` (`trino_src` -> `core`, `ops`)
4. `etl/10_build_daily_revenue.sql`, `etl/11_build_customer_ltv.sql` (the nightly job)
5. `reports/*.sql`
6. `recon/trino/*.sql` — every diff column must be 0
