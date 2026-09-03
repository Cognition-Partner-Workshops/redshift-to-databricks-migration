-- Nightly ETL: rebuild migration_demo.mart.customer_ltv.
-- Converted from sql/etl/11_build_customer_ltv.sql (Redshift).
--   AVG(DECIMAL(12,2))   -> Redshift keeps the input scale and truncates; Databricks widens the
--                           scale and rounds. Reproduced as SUM/COUNT truncated toward zero at
--                           scale 2 (FLOOR for non-negative, CEIL for negative).
--   DATEDIFF(day, a, b)  -> Redshift counts day-boundary crossings: DATEDIFF(date(b), date(a))
--   DISTKEY/SORTKEY      -> dropped (Delta); DROP + CREATE -> CREATE OR REPLACE
--   CHAR(10) compare     -> RTRIM (see 10_build_daily_revenue.sql)

CREATE OR REPLACE TABLE migration_demo.mart.customer_ltv
AS
SELECT
    c.customer_id,
    c.customer_code,
    c.region,
    MIN(o.order_ts)                                     AS first_order_ts,
    MAX(o.order_ts)                                     AS last_order_ts,
    COUNT(o.order_id)                                   AS lifetime_orders,
    CAST(SUM(o.order_total) AS DECIMAL(38,2))           AS lifetime_revenue,
    CAST(CASE WHEN SUM(o.order_total) < 0
              THEN CEIL(SUM(o.order_total) / COUNT(o.order_total), 2)
              ELSE FLOOR(SUM(o.order_total) / COUNT(o.order_total), 2)
         END AS DECIMAL(38,2))                          AS avg_order_value,
    DATEDIFF(CAST(MAX(o.order_ts) AS DATE), CAST(MIN(o.order_ts) AS DATE)) AS active_days
FROM migration_demo.core.customers c
JOIN migration_demo.core.orders o ON o.customer_id = c.customer_id
WHERE RTRIM(o.order_status) <> 'CANCELLED'
GROUP BY c.customer_id, c.customer_code, c.region;
