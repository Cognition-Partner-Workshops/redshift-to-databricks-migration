-- Row counts: migrated tables vs the trino_src snapshot exported from Trino. Every diff must be 0.
WITH c AS (
    SELECT 'core.orders' AS tbl, (SELECT count(*) FROM trino_migration_demo.core.orders) AS databricks_rows, (SELECT count(*) FROM trino_migration_demo.trino_src.core_orders) AS trino_rows
    UNION ALL SELECT 'core.order_items', (SELECT count(*) FROM trino_migration_demo.core.order_items), (SELECT count(*) FROM trino_migration_demo.trino_src.core_order_items)
    UNION ALL SELECT 'ops.customers', (SELECT count(*) FROM trino_migration_demo.ops.customers), (SELECT count(*) FROM trino_migration_demo.trino_src.ops_customers)
    UNION ALL SELECT 'ops.customer_tags', (SELECT count(*) FROM trino_migration_demo.ops.customer_tags), (SELECT count(*) FROM trino_migration_demo.trino_src.ops_customer_tags)
    UNION ALL SELECT 'mart.daily_revenue (rebuilt)', (SELECT count(*) FROM trino_migration_demo.mart.daily_revenue), (SELECT count(*) FROM trino_migration_demo.trino_src.mart_daily_revenue)
    UNION ALL SELECT 'mart.customer_ltv (rebuilt)', (SELECT count(*) FROM trino_migration_demo.mart.customer_ltv), (SELECT count(*) FROM trino_migration_demo.trino_src.mart_customer_ltv)
)
SELECT tbl, databricks_rows, trino_rows, databricks_rows - trino_rows AS diff
FROM c
ORDER BY tbl;
