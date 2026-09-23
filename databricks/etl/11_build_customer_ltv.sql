-- Gold: mart.customer_ltv, one row per customer with at least one valid order.
-- Translated from sql/etl/11_build_customer_ltv.sql.
--
-- The join and cancelled filter now live in silver.enriched_orders.
--   AVG(order_total)             -> canonical avg_order_value at 2 decimals (Redshift
--                                   published this mart's AOV as DECIMAL(38,2), truncated)
--   DATEDIFF(day, min, max)      -> datediff(to_date(max), to_date(min)): Redshift counts
--                                   day-boundary crossings, so compare dates not timestamps
--   DISTKEY/SORTKEY              -> CLUSTER BY
--   DROP + CTAS                  -> CREATE OR REPLACE TABLE (atomic swap, time travel)

CREATE OR REPLACE TABLE migration_demo.mart.customer_ltv
CLUSTER BY (customer_id)
COMMENT 'Lifetime orders, revenue, AOV and active span per customer over valid orders'
AS
SELECT
    e.customer_id,
    e.customer_code,
    e.region,
    MIN(e.order_ts)                                     AS first_order_ts,
    MAX(e.order_ts)                                     AS last_order_ts,
    COUNT(e.order_id)                                   AS lifetime_orders,
    CAST(SUM(e.order_total) AS DECIMAL(38,2))           AS lifetime_revenue,
    CAST(migration_demo.silver.avg_order_value(
        CAST(SUM(e.order_total) AS DECIMAL(38,2)),
        COUNT(e.order_id),
        2) AS DECIMAL(38,2))                            AS avg_order_value,
    CAST(datediff(to_date(MAX(e.order_ts)), to_date(MIN(e.order_ts))) AS BIGINT)
                                                        AS active_days
FROM migration_demo.silver.enriched_orders e
GROUP BY e.customer_id, e.customer_code, e.region;
