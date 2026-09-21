-- CROSS JOIN UNNEST(map_entries(attrs)) AS u(attr_key, attr_value) -> LATERAL VIEW explode(attrs).
-- approx_percentile(order_total, 0.5): Trino's implementation is randomized and returns a different median
-- on every run (see docs/evidence). Databricks percentile_approx is deterministic; with accuracy 10000 it
-- returns a true middle order value for 1,250 rows per group, so median_order_total is stable across runs.
-- AVG(DECIMAL(12,2)) is cast back to DECIMAL(12,2) to keep Trino's scale.
SELECT
    attr_value AS promo,
    COUNT(*) AS orders,
    percentile_approx(order_total, 0.5, 10000) AS median_order_total,
    CAST(AVG(order_total) AS DECIMAL(12, 2)) AS average_order_total
FROM trino_migration_demo.core.orders o
LATERAL VIEW explode(o.attrs) u AS attr_key, attr_value
WHERE attr_key = 'promo'
GROUP BY attr_value
ORDER BY median_order_total DESC;
