-- Nightly ETL: rebuild mart.customer_ltv.
--
-- Conversion notes (Redshift -> Databricks):
--   DATEDIFF(day, a, b)  -> DATEDIFF(CAST(b AS DATE), CAST(a AS DATE)).
--                           Redshift counts day-boundary crossings, while
--                           Databricks DATEDIFF(DAY, a, b) counts complete
--                           24-hour intervals, so diff the calendar dates.
--   CHAR(10) status      -> RTRIM before comparing
--   AVG(DECIMAL(12,2))   -> Redshift returns DECIMAL(38,2) and TRUNCATES the
--                           quotient (Databricks AVG rounds), so compute
--                           SUM/COUNT and truncate to 2 decimals explicitly.

CREATE OR REPLACE TABLE migration_demo.mart.customer_ltv
AS
SELECT
    c.customer_id,
    c.customer_code,
    c.region,
    MIN(o.order_ts)                          AS first_order_ts,
    MAX(o.order_ts)                          AS last_order_ts,
    COUNT(o.order_id)                        AS lifetime_orders,
    SUM(o.order_total)                       AS lifetime_revenue,
    CAST(FLOOR(SUM(o.order_total) / COUNT(o.order_id) * 100) / 100
         AS DECIMAL(38,2))                   AS avg_order_value,
    DATEDIFF(CAST(MAX(o.order_ts) AS DATE), CAST(MIN(o.order_ts) AS DATE)) AS active_days
FROM migration_demo.core.customers c
JOIN migration_demo.core.orders o ON o.customer_id = c.customer_id
WHERE RTRIM(o.order_status) <> 'CANCELLED'
GROUP BY c.customer_id, c.customer_code, c.region;
