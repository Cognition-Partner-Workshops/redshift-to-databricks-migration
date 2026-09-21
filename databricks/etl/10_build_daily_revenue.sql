-- Converted from trino/sql/etl/10_build_daily_revenue.sql
-- approx_distinct(order_id) -> COUNT(DISTINCT order_id): order_id is unique, the exact count is
-- what the sketch estimates. Trino's DECIMAL(38,2) / BIGINT yields DECIMAL(38,6) (half-up). The Databricks quotient
-- is also scale 6 and is cast explicitly to pin the type.
CREATE OR REPLACE TABLE trino_migration_demo.mart.daily_revenue
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS
SELECT
    date_trunc('day', o.order_ts) AS order_date,
    c.region,
    IF(try_element_at(o.attrs, 'promo') = 'NONE', 'ORGANIC', 'PROMOTIONAL') AS promo_group,
    COUNT(DISTINCT o.order_id) AS order_count,
    CAST(SUM(try_cast(o.order_total AS DECIMAL(12, 2))) AS DECIMAL(38, 2)) AS gross_revenue,
    CAST(SUM(try_cast(o.order_total AS DECIMAL(12, 2)))
        / NULLIF(COUNT(DISTINCT o.order_id), 0) AS DECIMAL(38, 6)) AS avg_order_value
FROM trino_migration_demo.core.orders o
JOIN trino_migration_demo.ops.customers c ON c.customer_id = o.customer_id
WHERE o.order_status <> 'CANCELLED'
  AND o.order_ts < date_trunc('day', CAST(current_timestamp() AS TIMESTAMP_NTZ))
GROUP BY 1, 2, 3;
