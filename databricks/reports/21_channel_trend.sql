-- BI report: 30-day channel trend
-- Converted from Redshift: DATEADD(day, -30, TRUNC(GETDATE())) -> date_add(current_date(), -30)
SELECT
    order_date,
    channel_group,
    SUM(gross_revenue) AS revenue,
    SUM(order_count)   AS orders
FROM migration_demo.mart.daily_revenue
WHERE order_date >= date_add(current_date(), -30)
GROUP BY order_date, channel_group
ORDER BY order_date, channel_group;
