-- Per-column aggregates on the marts, Trino snapshot vs Databricks, to the cent.
SELECT 'daily_revenue' AS mart, 'trino' AS side,
       COUNT(*)                          AS rows_,
       SUM(order_count)                  AS sum_orders,
       SUM(gross_revenue)                AS sum_gross,
       ROUND(SUM(avg_order_value), 2)    AS sum_aov,
       MIN(order_date)                   AS min_date,
       MAX(order_date)                   AS max_date
FROM trino_migration_demo.trino_src.mart_daily_revenue
UNION ALL
SELECT 'daily_revenue', 'databricks',
       COUNT(*), SUM(order_count), SUM(gross_revenue), ROUND(SUM(avg_order_value), 2),
       MIN(order_date), MAX(order_date)
FROM trino_migration_demo.mart.daily_revenue
UNION ALL
SELECT 'customer_ltv', 'trino',
       COUNT(*), SUM(lifetime_orders), SUM(lifetime_revenue), ROUND(SUM(avg_order_value), 2),
       CAST(MIN(first_order_ts) AS DATE), CAST(MAX(last_order_ts) AS DATE)
FROM trino_migration_demo.trino_src.mart_customer_ltv
UNION ALL
SELECT 'customer_ltv', 'databricks',
       COUNT(*), SUM(lifetime_orders), SUM(lifetime_revenue), ROUND(SUM(avg_order_value), 2),
       CAST(MIN(first_order_ts) AS DATE), CAST(MAX(last_order_ts) AS DATE)
FROM trino_migration_demo.mart.customer_ltv
ORDER BY mart, side
