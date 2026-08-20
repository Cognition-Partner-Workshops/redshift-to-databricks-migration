-- Nightly ETL: rebuild mart.daily_revenue from core.orders.
--
-- Conversion notes (Redshift -> Databricks):
--   TRUNC(ts)            -> CAST(ts AS DATE)
--   DECODE(...)          -> CASE
--   GETDATE()            -> CURRENT_DATE for the day boundary
--   CHAR(10) status      -> RTRIM before comparing (Databricks strings keep padding)
--   avg_order_value      -> Redshift decimal division yields DECIMAL(38,4) and
--                           TRUNCATES (Databricks rounds), so truncate explicitly.

CREATE OR REPLACE TABLE migration_demo.mart.daily_revenue
AS
SELECT
    CAST(o.order_ts AS DATE)                            AS order_date,
    c.region,
    CASE o.sales_channel
        WHEN 'web' THEN 'ONLINE'
        WHEN 'app' THEN 'ONLINE'
        ELSE 'RETAIL'
    END                                                 AS channel_group,
    COUNT(DISTINCT o.order_id)                          AS order_count,
    SUM(o.order_total)                                  AS gross_revenue,
    CAST(FLOOR(SUM(o.order_total) / NULLIF(COUNT(DISTINCT o.order_id), 0) * 10000) / 10000
         AS DECIMAL(38,4))                              AS avg_order_value
FROM migration_demo.core.orders o
JOIN migration_demo.core.customers c ON c.customer_id = o.customer_id
WHERE RTRIM(o.order_status) <> 'CANCELLED'
  AND o.order_ts < CAST(CURRENT_DATE AS TIMESTAMP)
GROUP BY 1, 2, 3;
