-- Land the Redshift core tables in Unity Catalog as Delta, read live through the
-- redshift_src foreign catalog (Lakehouse Federation connection redshift_demo).
-- Re-runnable: each statement fully replaces the target table.

CREATE SCHEMA IF NOT EXISTS migration_demo.core;
CREATE SCHEMA IF NOT EXISTS migration_demo.mart;

CREATE OR REPLACE TABLE migration_demo.core.customers AS
SELECT * FROM redshift_src.core.customers;

CREATE OR REPLACE TABLE migration_demo.core.orders AS
SELECT * FROM redshift_src.core.orders;

CREATE OR REPLACE TABLE migration_demo.core.order_items AS
SELECT * FROM redshift_src.core.order_items;
