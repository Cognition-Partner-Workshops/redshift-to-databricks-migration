-- BI report: 30-day channel trend
SELECT
    order_date,
    channel_group,
    SUM(gross_revenue) AS revenue,
    SUM(order_count)   AS orders
FROM mart.daily_revenue
WHERE order_date >= DATEADD(day, -30, TRUNC(GETDATE()))
GROUP BY order_date, channel_group
ORDER BY order_date, channel_group;
