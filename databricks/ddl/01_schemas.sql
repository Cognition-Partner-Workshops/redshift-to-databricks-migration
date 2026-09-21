-- Trino: lake.core / lake.mart (Hive, file:///data/warehouse) and ops.public (Postgres).
-- Databricks: one Unity Catalog catalog; the two storage systems collapse into schemas.
CREATE CATALOG IF NOT EXISTS trino_migration_demo
COMMENT 'Trino order-analytics estate (lake + ops catalogs) migrated to Databricks';

CREATE SCHEMA IF NOT EXISTS trino_migration_demo.trino_src
COMMENT 'Raw snapshot of the six Trino tables as exported (types preserved). Reconciliation baseline. Never rebuilt.';

CREATE SCHEMA IF NOT EXISTS trino_migration_demo.core
COMMENT 'Was lake.core (Hive/Parquet)';

CREATE SCHEMA IF NOT EXISTS trino_migration_demo.ops
COMMENT 'Was ops.public (PostgreSQL)';

CREATE SCHEMA IF NOT EXISTS trino_migration_demo.mart
COMMENT 'Was lake.mart (Hive/Parquet, external_location). Rebuilt nightly by databricks/etl.';

CREATE VOLUME IF NOT EXISTS trino_migration_demo.trino_src.landing
COMMENT 'CSV exports from the Trino CLI (workspace cannot reach Trino)';
