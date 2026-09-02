-- Core-table backfill: Redshift -> Delta via Lakehouse Federation (redshift_src).
-- Like-for-like copy; column names and types are preserved as exposed by the
-- foreign catalog. Re-runnable (CREATE OR REPLACE).

CREATE SCHEMA IF NOT EXISTS migration_demo.core;
CREATE SCHEMA IF NOT EXISTS migration_demo.mart;

CREATE OR REPLACE TABLE migration_demo.core.customers AS
SELECT * FROM redshift_src.core.customers;

CREATE OR REPLACE TABLE migration_demo.core.orders AS
SELECT * FROM redshift_src.core.orders;

CREATE OR REPLACE TABLE migration_demo.core.order_items AS
SELECT * FROM redshift_src.core.order_items;
