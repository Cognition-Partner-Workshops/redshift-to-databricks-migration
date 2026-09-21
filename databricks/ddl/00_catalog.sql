-- Unity Catalog layout for the Trino migration.
--   core      - converted lake.core tables
--   ops       - converted ops.public tables (Postgres side of the Trino estate)
--   mart      - marts rebuilt by the converted Databricks SQL
--   trino_src - raw CSV snapshot exported from the running Trino estate + typed
--               snapshots of the Trino marts, used as the reconciliation baseline
CREATE CATALOG IF NOT EXISTS trino_migration_demo_run4;
CREATE SCHEMA IF NOT EXISTS trino_migration_demo_run4.core;
CREATE SCHEMA IF NOT EXISTS trino_migration_demo_run4.ops;
CREATE SCHEMA IF NOT EXISTS trino_migration_demo_run4.mart;
CREATE SCHEMA IF NOT EXISTS trino_migration_demo_run4.trino_src;
CREATE VOLUME IF NOT EXISTS trino_migration_demo_run4.trino_src.landing;
