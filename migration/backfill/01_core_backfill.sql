-- One-time backfill of the core tables from Redshift into Unity Catalog Delta tables.
-- Source: foreign catalog redshift_src (Lakehouse Federation connection redshift_demo).
-- Rows are copied as-is: CHAR columns keep Redshift's blank padding (see docs/ASSESSMENT.md, R2).

CREATE OR REPLACE TABLE migration_demo.core.customers
USING DELTA
AS SELECT * FROM redshift_src.core.customers;

CREATE OR REPLACE TABLE migration_demo.core.orders
USING DELTA
AS SELECT * FROM redshift_src.core.orders;

CREATE OR REPLACE TABLE migration_demo.core.order_items
USING DELTA
AS SELECT * FROM redshift_src.core.order_items;
