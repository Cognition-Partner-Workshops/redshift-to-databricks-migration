-- Symmetric row differences (full rows, all columns) between the rebuilt marts and the Trino snapshot marts,
-- and between the migrated core/ops tables and the snapshot. Every count must be 0.
-- MAP columns cannot be compared with EXCEPT, so orders.attrs is compared as sorted map entries.
WITH
dr_db AS (SELECT order_date, CAST(region AS STRING) region, CAST(promo_group AS STRING) promo_group, order_count, gross_revenue, avg_order_value FROM trino_migration_demo.mart.daily_revenue),
dr_tr AS (SELECT order_date, CAST(region AS STRING) region, CAST(promo_group AS STRING) promo_group, order_count, gross_revenue, avg_order_value FROM trino_migration_demo.trino_src.mart_daily_revenue),
ltv_db AS (SELECT customer_id, CAST(customer_code AS STRING) customer_code, CAST(region AS STRING) region, first_order_ts, last_order_ts, lifetime_orders, lifetime_revenue, avg_order_value, active_days, first_order_month, tags FROM trino_migration_demo.mart.customer_ltv),
ltv_tr AS (SELECT customer_id, CAST(customer_code AS STRING) customer_code, CAST(region AS STRING) region, first_order_ts, last_order_ts, lifetime_orders, lifetime_revenue, avg_order_value, active_days, first_order_month, tags FROM trino_migration_demo.trino_src.mart_customer_ltv),
o_db AS (SELECT order_id, customer_id, order_ts, order_status, order_total, sales_channel, array_sort(map_entries(attrs)) attrs, order_date FROM trino_migration_demo.core.orders),
o_tr AS (SELECT order_id, customer_id, order_ts, order_status, order_total, sales_channel, array_sort(map_entries(attrs)) attrs, order_date FROM trino_migration_demo.trino_src.core_orders),
cu_db AS (SELECT customer_id, CAST(customer_code AS STRING) customer_code, CAST(full_name AS STRING) full_name, CAST(email AS STRING) email, CAST(region AS STRING) region, signup_date, is_active, created_at FROM trino_migration_demo.ops.customers),
cu_tr AS (SELECT customer_id, CAST(customer_code AS STRING) customer_code, CAST(full_name AS STRING) full_name, CAST(email AS STRING) email, CAST(region AS STRING) region, signup_date, is_active, created_at FROM trino_migration_demo.trino_src.ops_customers)
SELECT 'mart.daily_revenue' AS tbl, 'databricks EXCEPT trino' AS direction, count(*) AS rows FROM (SELECT * FROM dr_db EXCEPT ALL SELECT * FROM dr_tr)
UNION ALL SELECT 'mart.daily_revenue', 'trino EXCEPT databricks', count(*) FROM (SELECT * FROM dr_tr EXCEPT ALL SELECT * FROM dr_db)
UNION ALL SELECT 'mart.customer_ltv', 'databricks EXCEPT trino', count(*) FROM (SELECT * FROM ltv_db EXCEPT ALL SELECT * FROM ltv_tr)
UNION ALL SELECT 'mart.customer_ltv', 'trino EXCEPT databricks', count(*) FROM (SELECT * FROM ltv_tr EXCEPT ALL SELECT * FROM ltv_db)
UNION ALL SELECT 'core.orders', 'databricks EXCEPT trino', count(*) FROM (SELECT * FROM o_db EXCEPT ALL SELECT * FROM o_tr)
UNION ALL SELECT 'core.orders', 'trino EXCEPT databricks', count(*) FROM (SELECT * FROM o_tr EXCEPT ALL SELECT * FROM o_db)
UNION ALL SELECT 'core.order_items', 'databricks EXCEPT trino', count(*) FROM (SELECT * FROM trino_migration_demo.core.order_items EXCEPT ALL SELECT * FROM trino_migration_demo.trino_src.core_order_items)
UNION ALL SELECT 'core.order_items', 'trino EXCEPT databricks', count(*) FROM (SELECT * FROM trino_migration_demo.trino_src.core_order_items EXCEPT ALL SELECT * FROM trino_migration_demo.core.order_items)
UNION ALL SELECT 'ops.customers', 'databricks EXCEPT trino', count(*) FROM (SELECT * FROM cu_db EXCEPT ALL SELECT * FROM cu_tr)
UNION ALL SELECT 'ops.customers', 'trino EXCEPT databricks', count(*) FROM (SELECT * FROM cu_tr EXCEPT ALL SELECT * FROM cu_db)
UNION ALL SELECT 'ops.customer_tags', 'databricks EXCEPT trino', count(*) FROM (SELECT * FROM trino_migration_demo.ops.customer_tags EXCEPT ALL SELECT * FROM trino_migration_demo.trino_src.ops_customer_tags)
UNION ALL SELECT 'ops.customer_tags', 'trino EXCEPT databricks', count(*) FROM (SELECT * FROM trino_migration_demo.trino_src.ops_customer_tags EXCEPT ALL SELECT * FROM trino_migration_demo.ops.customer_tags)
ORDER BY tbl, direction;
