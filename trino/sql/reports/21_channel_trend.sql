SELECT
    order_date,
    promo_group,
    SUM(gross_revenue) AS revenue,
    SUM(order_count) AS orders
FROM lake.mart.daily_revenue
WHERE order_date >= date_add('day', -30, current_date)
GROUP BY order_date, promo_group
ORDER BY order_date, promo_group;
