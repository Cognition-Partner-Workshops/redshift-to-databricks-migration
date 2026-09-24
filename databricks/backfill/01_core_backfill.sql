-- Backfill migration_demo.core.* from live Redshift through the redshift_src foreign
-- catalog (Lakehouse Federation connection redshift_demo).
--
-- Run databricks/ddl/01_schemas.sql and databricks/ddl/02_core_tables.sql first.
-- Re-runnable: INSERT OVERWRITE fully replaces each table's contents while keeping the
-- DDL (types, NOT NULL, clustering) from 02_core_tables.sql. Re-run to resync after
-- source drift (scripts/drift_loader.py lands new orders in Redshift).
--
-- order_items has no downstream ETL/report consumer. It is loaded so count parity
-- covers all three core tables.

INSERT OVERWRITE migration_demo.core.customers
SELECT customer_id, customer_code, full_name, email, region, signup_date, is_active, created_at
FROM redshift_src.core.customers;

INSERT OVERWRITE migration_demo.core.orders
SELECT order_id, customer_id, order_ts, order_status, order_total, sales_channel, loaded_at
FROM redshift_src.core.orders;

INSERT OVERWRITE migration_demo.core.order_items
SELECT order_item_id, order_id, sku, quantity, unit_price, discount_pct
FROM redshift_src.core.order_items;
