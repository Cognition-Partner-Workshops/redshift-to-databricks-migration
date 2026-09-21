CREATE OR REPLACE TABLE trino_migration_demo.mart.daily_revenue
USING DELTA
AS
SELECT
    DATE_TRUNC('DAY', o.order_ts) AS order_date,
    c.region,
    IF(element_at(o.attrs, 'promo') = 'NONE', 'ORGANIC', 'PROMOTIONAL') AS promo_group,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(TRY_CAST(o.order_total AS DECIMAL(12, 2))) AS gross_revenue,
    CAST(
        SUM(TRY_CAST(o.order_total AS DECIMAL(12, 2)))
            / NULLIF(COUNT(DISTINCT o.order_id), 0)
        AS DECIMAL(38, 2)
    ) AS avg_order_value
FROM trino_migration_demo.core.orders o
JOIN trino_migration_demo.ops.customers c ON c.customer_id = o.customer_id
WHERE o.order_status <> 'CANCELLED'
  AND o.order_ts < DATE_TRUNC('DAY', CURRENT_TIMESTAMP())
GROUP BY 1, 2, 3;
