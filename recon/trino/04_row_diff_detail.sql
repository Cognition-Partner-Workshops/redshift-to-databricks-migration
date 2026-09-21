-- Diagnostic: show the differing rows side by side (run only when 03 reports non-zero).
SELECT 'trino' AS side, * FROM (
    SELECT CAST(order_date AS STRING) AS order_date, region, promo_group, order_count,
           CAST(gross_revenue AS STRING) AS gross_revenue, CAST(avg_order_value AS STRING) AS avg_order_value
    FROM trino_migration_demo.trino_src.mart_daily_revenue
    EXCEPT ALL
    SELECT CAST(order_date AS STRING), region, promo_group, order_count,
           CAST(gross_revenue AS STRING), CAST(avg_order_value AS STRING)
    FROM trino_migration_demo.mart.daily_revenue)
UNION ALL
SELECT 'dbx', * FROM (
    SELECT CAST(order_date AS STRING) AS order_date, region, promo_group, order_count,
           CAST(gross_revenue AS STRING), CAST(avg_order_value AS STRING)
    FROM trino_migration_demo.mart.daily_revenue
    EXCEPT ALL
    SELECT CAST(order_date AS STRING), region, promo_group, order_count,
           CAST(gross_revenue AS STRING), CAST(avg_order_value AS STRING)
    FROM trino_migration_demo.trino_src.mart_daily_revenue)
ORDER BY order_date, region, promo_group, side
LIMIT 50;

SELECT 'trino' AS side, * FROM (
    SELECT customer_id, customer_code, region, CAST(first_order_ts AS STRING) AS first_order_ts,
           CAST(last_order_ts AS STRING) AS last_order_ts, lifetime_orders,
           CAST(lifetime_revenue AS STRING) AS lifetime_revenue, CAST(avg_order_value AS STRING) AS avg_order_value,
           active_days, first_order_month, to_json(tags) AS tags
    FROM trino_migration_demo.trino_src.mart_customer_ltv
    EXCEPT ALL
    SELECT customer_id, customer_code, region, CAST(first_order_ts AS STRING), CAST(last_order_ts AS STRING),
           lifetime_orders, CAST(lifetime_revenue AS STRING), CAST(avg_order_value AS STRING),
           active_days, first_order_month, to_json(tags)
    FROM trino_migration_demo.mart.customer_ltv)
UNION ALL
SELECT 'dbx', * FROM (
    SELECT customer_id, customer_code, region, CAST(first_order_ts AS STRING), CAST(last_order_ts AS STRING),
           lifetime_orders, CAST(lifetime_revenue AS STRING), CAST(avg_order_value AS STRING),
           active_days, first_order_month, to_json(tags)
    FROM trino_migration_demo.mart.customer_ltv
    EXCEPT ALL
    SELECT customer_id, customer_code, region, CAST(first_order_ts AS STRING), CAST(last_order_ts AS STRING),
           lifetime_orders, CAST(lifetime_revenue AS STRING), CAST(avg_order_value AS STRING),
           active_days, first_order_month, to_json(tags)
    FROM trino_migration_demo.trino_src.mart_customer_ltv)
ORDER BY customer_id, side
LIMIT 50;
