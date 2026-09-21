-- Row counts: Trino snapshot (trino_src) vs converted Databricks objects.
SELECT 'core.orders' AS object,
       (SELECT COUNT(*) FROM trino_migration_demo.trino_src.core_orders)      AS trino_rows,
       (SELECT COUNT(*) FROM trino_migration_demo.core.orders)                AS dbx_rows
UNION ALL
SELECT 'core.order_items',
       (SELECT COUNT(*) FROM trino_migration_demo.trino_src.core_order_items),
       (SELECT COUNT(*) FROM trino_migration_demo.core.order_items)
UNION ALL
SELECT 'ops.customers',
       (SELECT COUNT(*) FROM trino_migration_demo.trino_src.ops_customers),
       (SELECT COUNT(*) FROM trino_migration_demo.ops.customers)
UNION ALL
SELECT 'ops.customer_tags',
       (SELECT COUNT(*) FROM trino_migration_demo.trino_src.ops_customer_tags),
       (SELECT COUNT(*) FROM trino_migration_demo.ops.customer_tags)
UNION ALL
SELECT 'mart.daily_revenue',
       (SELECT COUNT(*) FROM trino_migration_demo.trino_src.mart_daily_revenue),
       (SELECT COUNT(*) FROM trino_migration_demo.mart.daily_revenue)
UNION ALL
SELECT 'mart.customer_ltv',
       (SELECT COUNT(*) FROM trino_migration_demo.trino_src.mart_customer_ltv),
       (SELECT COUNT(*) FROM trino_migration_demo.mart.customer_ltv)
