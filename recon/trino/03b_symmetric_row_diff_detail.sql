-- Detail rows behind any non-zero count in 03_symmetric_row_diff.sql (marts only). Empty when recon is green.
SELECT 'databricks_only' AS side, * FROM (
    SELECT customer_id, CAST(customer_code AS STRING) customer_code, CAST(region AS STRING) region, first_order_ts, last_order_ts, lifetime_orders, lifetime_revenue, avg_order_value, active_days, first_order_month, tags FROM trino_migration_demo.mart.customer_ltv
    EXCEPT ALL
    SELECT customer_id, CAST(customer_code AS STRING), CAST(region AS STRING), first_order_ts, last_order_ts, lifetime_orders, lifetime_revenue, avg_order_value, active_days, first_order_month, tags FROM trino_migration_demo.trino_src.mart_customer_ltv)
UNION ALL
SELECT 'trino_only', * FROM (
    SELECT customer_id, CAST(customer_code AS STRING) customer_code, CAST(region AS STRING) region, first_order_ts, last_order_ts, lifetime_orders, lifetime_revenue, avg_order_value, active_days, first_order_month, tags FROM trino_migration_demo.trino_src.mart_customer_ltv
    EXCEPT ALL
    SELECT customer_id, CAST(customer_code AS STRING), CAST(region AS STRING), first_order_ts, last_order_ts, lifetime_orders, lifetime_revenue, avg_order_value, active_days, first_order_month, tags FROM trino_migration_demo.mart.customer_ltv)
ORDER BY customer_id, side;

SELECT 'databricks_only' AS side, * FROM (
    SELECT order_date, CAST(region AS STRING) region, CAST(promo_group AS STRING) promo_group, order_count, gross_revenue, avg_order_value FROM trino_migration_demo.mart.daily_revenue
    EXCEPT ALL
    SELECT order_date, CAST(region AS STRING), CAST(promo_group AS STRING), order_count, gross_revenue, avg_order_value FROM trino_migration_demo.trino_src.mart_daily_revenue)
UNION ALL
SELECT 'trino_only', * FROM (
    SELECT order_date, CAST(region AS STRING) region, CAST(promo_group AS STRING) promo_group, order_count, gross_revenue, avg_order_value FROM trino_migration_demo.trino_src.mart_daily_revenue
    EXCEPT ALL
    SELECT order_date, CAST(region AS STRING), CAST(promo_group AS STRING), order_count, gross_revenue, avg_order_value FROM trino_migration_demo.mart.daily_revenue)
ORDER BY order_date, region, promo_group, side;
