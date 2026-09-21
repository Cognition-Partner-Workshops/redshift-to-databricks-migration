-- Converted from trino/sql/reports/22_promo_lift.sql
-- Trino coerces DECIMAL(12,2) to REAL for approx_percentile and estimates the median with a
-- t-digest, whose output varies between runs on identical data. Databricks percentile_approx
-- uses a different sketch and returns an observed value. The result is cast to FLOAT to match
-- Trino's REAL output type. Exact parity on this column is not achievable (see recon README).
SELECT
    attr_value AS promo,
    COUNT(*) AS orders,
    CAST(percentile_approx(order_total, 0.5) AS FLOAT) AS median_order_total,
    CAST(AVG(order_total) AS DECIMAL(12, 2)) AS average_order_total
FROM trino_migration_demo.core.orders o
LATERAL VIEW explode(o.attrs) u AS attr_key, attr_value
WHERE attr_key = 'promo'
GROUP BY attr_value
ORDER BY median_order_total DESC;
