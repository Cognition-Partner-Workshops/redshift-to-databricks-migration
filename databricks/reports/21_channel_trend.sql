-- BI report: 30-day channel trend
-- Converted from sql/reports/21_channel_trend.sql (Redshift).
-- DATEADD(day, -30, TRUNC(GETDATE())) -> DATE_ADD(current_date(), -30)  (session TZ is Etc/UTC)
SELECT
    order_date,
    channel_group,
    SUM(gross_revenue) AS revenue,
    SUM(order_count)   AS orders
FROM migration_demo.mart.daily_revenue
WHERE order_date >= DATE_ADD(current_date(), -30)
GROUP BY order_date, channel_group
ORDER BY order_date, channel_group
