SELECT
    attr_value AS promo,
    COUNT(*) AS orders,
    approx_percentile(order_total, 0.5) AS median_order_total,
    AVG(order_total) AS average_order_total
FROM lake.core.orders o
CROSS JOIN UNNEST(map_entries(o.attrs)) AS u(attr_key, attr_value)
WHERE attr_key = 'promo'
GROUP BY attr_value
ORDER BY median_order_total DESC;
