SELECT
    attr_value AS promo,
    COUNT(*) AS orders,
    CAST(percentile(order_total, 0.5) AS FLOAT) AS median_order_total,
    CAST(AVG(order_total) AS DECIMAL(12,2)) AS average_order_total
FROM trino_migration_demo.core.orders o
LATERAL VIEW EXPLODE(o.attrs) u AS attr_key, attr_value
WHERE attr_key = 'promo'
GROUP BY attr_value
ORDER BY median_order_total DESC NULLS LAST, promo NULLS LAST;
