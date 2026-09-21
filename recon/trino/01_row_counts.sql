-- Row counts: rebuilt Databricks mart vs the Trino snapshot it must reproduce.
SELECT
    'daily_revenue' AS table_name,
    (SELECT count(*) FROM trino_migration_demo_run4.trino_src.daily_revenue) AS trino_rows,
    (SELECT count(*) FROM trino_migration_demo_run4.mart.daily_revenue)      AS databricks_rows,
    (SELECT count(*) FROM trino_migration_demo_run4.mart.daily_revenue)
      - (SELECT count(*) FROM trino_migration_demo_run4.trino_src.daily_revenue) AS delta
UNION ALL
SELECT
    'customer_ltv',
    (SELECT count(*) FROM trino_migration_demo_run4.trino_src.customer_ltv),
    (SELECT count(*) FROM trino_migration_demo_run4.mart.customer_ltv),
    (SELECT count(*) FROM trino_migration_demo_run4.mart.customer_ltv)
      - (SELECT count(*) FROM trino_migration_demo_run4.trino_src.customer_ltv)
UNION ALL
SELECT
    'core.orders (landed vs exported)',
    (SELECT count(*) FROM trino_migration_demo_run4.trino_src.orders_raw),
    (SELECT count(*) FROM trino_migration_demo_run4.core.orders),
    (SELECT count(*) FROM trino_migration_demo_run4.core.orders)
      - (SELECT count(*) FROM trino_migration_demo_run4.trino_src.orders_raw)
UNION ALL
SELECT
    'core.order_items (landed vs exported)',
    (SELECT count(*) FROM trino_migration_demo_run4.trino_src.order_items_raw),
    (SELECT count(*) FROM trino_migration_demo_run4.core.order_items),
    (SELECT count(*) FROM trino_migration_demo_run4.core.order_items)
      - (SELECT count(*) FROM trino_migration_demo_run4.trino_src.order_items_raw)
UNION ALL
SELECT
    'ops.customers (landed vs exported)',
    (SELECT count(*) FROM trino_migration_demo_run4.trino_src.customers_raw),
    (SELECT count(*) FROM trino_migration_demo_run4.ops.customers),
    (SELECT count(*) FROM trino_migration_demo_run4.ops.customers)
      - (SELECT count(*) FROM trino_migration_demo_run4.trino_src.customers_raw)
UNION ALL
SELECT
    'ops.customer_tags (landed vs exported)',
    (SELECT count(*) FROM trino_migration_demo_run4.trino_src.customer_tags_raw),
    (SELECT count(*) FROM trino_migration_demo_run4.ops.customer_tags),
    (SELECT count(*) FROM trino_migration_demo_run4.ops.customer_tags)
      - (SELECT count(*) FROM trino_migration_demo_run4.trino_src.customer_tags_raw)
ORDER BY table_name
