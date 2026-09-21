-- Converted from trino/sql/etl/10_build_daily_revenue.sql
-- Conversion notes:
--   element_at(attrs, 'promo')  -> attrs['promo']          (same NULL-on-missing-key semantics)
--   approx_distinct(order_id)   -> COUNT(DISTINCT order_id) (see docs/ASSESSMENT.md - the
--       Trino HLL result is exact at this cardinality, so the exact count reproduces it and
--       removes the run-to-run drift approx_count_distinct would keep)
--   SUM(DECIMAL(12,2))          -> cast back to DECIMAL(38,2), Databricks widens to (22,2)
--   sum / count                 -> cast to DECIMAL(38,6), the type Trino's decimal division gives
--   current_timestamp           -> cast to TIMESTAMP_NTZ so the day boundary is compared
--                                  wall-clock to wall-clock, as in Trino
-- The table is declared before the insert so the column types match Trino's DESCRIBE
-- (CHAR(4) region, VARCHAR(11) promo_group, TIMESTAMP_NTZ order_date) - a CTAS would
-- widen CHAR/VARCHAR to STRING and TIMESTAMP_NTZ to zoned TIMESTAMP.
CREATE OR REPLACE TABLE trino_migration_demo_run4.mart.daily_revenue (
    order_date      TIMESTAMP_NTZ,
    region          CHAR(4),
    promo_group     VARCHAR(11),
    order_count     BIGINT,
    gross_revenue   DECIMAL(38, 2),
    avg_order_value DECIMAL(38, 6)
) TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported');

INSERT INTO trino_migration_demo_run4.mart.daily_revenue
SELECT
    CAST(date_trunc('DAY', o.order_ts) AS TIMESTAMP_NTZ)             AS order_date,
    c.region                                                         AS region,
    if(o.attrs['promo'] = 'NONE', 'ORGANIC', 'PROMOTIONAL')          AS promo_group,
    COUNT(DISTINCT o.order_id)                                       AS order_count,
    CAST(SUM(CAST(o.order_total AS DECIMAL(12, 2))) AS DECIMAL(38, 2)) AS gross_revenue,
    CAST(
        CAST(SUM(CAST(o.order_total AS DECIMAL(12, 2))) AS DECIMAL(38, 2))
        / NULLIF(COUNT(DISTINCT o.order_id), 0)
    AS DECIMAL(38, 6))                                               AS avg_order_value
FROM trino_migration_demo_run4.core.orders o
JOIN trino_migration_demo_run4.ops.customers c ON c.customer_id = o.customer_id
WHERE o.order_status <> 'CANCELLED'
  AND o.order_ts < date_trunc('DAY', CAST(current_timestamp() AS TIMESTAMP_NTZ))
GROUP BY 1, 2, 3
