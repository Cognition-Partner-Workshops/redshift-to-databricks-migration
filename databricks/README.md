# Databricks target for the Trino estate

Run order against the existing SQL warehouse (`DATABRICKS_DEMO_HOST` / `DATABRICKS_DEMO_TOKEN`):

1. `export_trino_to_csv.sh` - dumps the six tables out of the running Trino stack into
   `/home/ubuntu/demo/export`. MAP and ARRAY columns go out as JSON text (`json_format`),
   because Trino cannot cast them straight to VARCHAR.
2. Upload those CSVs to `/Volumes/trino_migration_demo_run4/trino_src/landing/`.
3. `ddl/00_catalog.sql` - catalog, schemas, landing volume.
4. `ddl/01_raw_snapshot.sql` - all-STRING raw tables read from the volume. `escape => '"'`
   matters: without it the doubled quotes inside the JSON columns shift every later field.
5. `ddl/02_core_ops_tables.sql` - typed `core` and `ops` tables.
6. `ddl/03_trino_mart_snapshot.sql` - typed copies of the two Trino marts. These are the
   reconciliation baseline and are never rebuilt from the converted SQL.
7. `etl/10_build_daily_revenue.sql`, `etl/11_build_customer_ltv.sql` - rebuild the marts.
8. `reports/*.sql` - the three converted reports.
9. `../recon/trino/*.sql` - the reconciliation suite.

Each converted file carries its Trino-to-Databricks differences as a header comment.
`docs/ASSESSMENT.md` ranks the source files by migration risk and
`docs/evidence/run-4/` holds the before and after output.
