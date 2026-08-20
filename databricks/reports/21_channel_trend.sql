-- BI report: 30-day channel trend
SELECT
    order_date,
    channel_group,
    SUM(gross_revenue) AS revenue,
    SUM(order_count)   AS orders
FROM migration_demo.mart.daily_revenue
WHERE order_date >= DATE_ADD(CURRENT_DATE, -30)
GROUP BY order_date, channel_group
ORDER BY order_date, channel_group;
