-- Row counts: Trino snapshot (trino_src) vs migrated objects. All six must have diff = 0.
WITH c AS (
    SELECT 'lake.core.orders' AS object,
           (SELECT count(*) FROM trino_migration_demo.trino_src.core_orders) AS trino_rows,
           (SELECT count(*) FROM trino_migration_demo.core.orders) AS dbx_rows
    UNION ALL SELECT 'lake.core.order_items',
           (SELECT count(*) FROM trino_migration_demo.trino_src.core_order_items),
           (SELECT count(*) FROM trino_migration_demo.core.order_items)
    UNION ALL SELECT 'ops.public.customers',
           (SELECT count(*) FROM trino_migration_demo.trino_src.ops_customers),
           (SELECT count(*) FROM trino_migration_demo.ops.customers)
    UNION ALL SELECT 'ops.public.customer_tags',
           (SELECT count(*) FROM trino_migration_demo.trino_src.ops_customer_tags),
           (SELECT count(*) FROM trino_migration_demo.ops.customer_tags)
    UNION ALL SELECT 'lake.mart.daily_revenue',
           (SELECT count(*) FROM trino_migration_demo.trino_src.mart_daily_revenue),
           (SELECT count(*) FROM trino_migration_demo.mart.daily_revenue)
    UNION ALL SELECT 'lake.mart.customer_ltv',
           (SELECT count(*) FROM trino_migration_demo.trino_src.mart_customer_ltv),
           (SELECT count(*) FROM trino_migration_demo.mart.customer_ltv)
)
SELECT object, trino_rows, dbx_rows, dbx_rows - trino_rows AS diff,
       IF(dbx_rows = trino_rows, 'PASS', 'FAIL') AS verdict
FROM c ORDER BY object;
