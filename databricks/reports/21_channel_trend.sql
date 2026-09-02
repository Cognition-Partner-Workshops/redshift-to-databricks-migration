-- BI report: 30-day channel trend
-- Converted from sql/reports/21_channel_trend.sql.
-- DATEADD(day, -30, TRUNC(GETDATE())) -> DATE_SUB(current_date(), 30)
SELECT
    order_date,
    channel_group,
    CAST(SUM(gross_revenue) AS DECIMAL(38,2)) AS revenue,
    SUM(order_count)                          AS orders
FROM migration_demo.mart.daily_revenue
WHERE order_date >= DATE_SUB(current_date(), 30)
GROUP BY order_date, channel_group
ORDER BY order_date, channel_group;
