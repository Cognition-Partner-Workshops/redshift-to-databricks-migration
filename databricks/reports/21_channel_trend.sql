-- Converted from trino/sql/reports/21_channel_trend.sql
--   date_add('day', -30, current_date) -> date_sub(current_date(), 30)
SELECT
    order_date,
    promo_group,
    CAST(SUM(gross_revenue) AS DECIMAL(38, 2)) AS revenue,
    SUM(order_count)                           AS orders
FROM trino_migration_demo_run4.mart.daily_revenue
WHERE order_date >= date_sub(current_date(), 30)
GROUP BY order_date, promo_group
ORDER BY order_date, promo_group
