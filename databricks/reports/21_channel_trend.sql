SELECT
    order_date,
    promo_group,
    SUM(gross_revenue) AS revenue,
    SUM(order_count) AS orders
FROM trino_migration_demo.mart.daily_revenue
WHERE order_date >= date_add(current_date(), -30)
GROUP BY order_date, promo_group
ORDER BY order_date, promo_group;
