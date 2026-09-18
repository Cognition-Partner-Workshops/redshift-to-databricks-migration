-- Nightly ETL: rebuild migration_demo.mart.daily_revenue from migration_demo.core.orders.
-- Converted from sql/etl/10_build_daily_revenue.sql (Redshift).
--   TRUNC(timestamp)   -> CAST(... AS DATE)
--   DECODE(...)        -> CASE
--   TRUNC(GETDATE())   -> current_date() (warehouse session timezone is UTC, matching Redshift)
--   DISTSTYLE/SORTKEY  -> dropped (Delta), and DROP + CREATE -> CREATE OR REPLACE
--   CHAR(10) compare   -> RTRIM, because Redshift ignores trailing blanks on CHAR and Delta
--                         STRING does not
-- Redshift DECIMAL division truncates toward zero at the result scale while Databricks rounds,
-- so the quotient is truncated explicitly at scale 4.

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
    CAST(SUM(o.order_total) AS DECIMAL(38,2))           AS gross_revenue,
    CAST(CASE WHEN SUM(o.order_total) < 0
              THEN CEIL(SUM(o.order_total) / NULLIF(COUNT(DISTINCT o.order_id), 0), 4)
              ELSE FLOOR(SUM(o.order_total) / NULLIF(COUNT(DISTINCT o.order_id), 0), 4)
         END AS DECIMAL(38,4))                          AS avg_order_value
FROM migration_demo.core.orders o
JOIN migration_demo.core.customers c ON c.customer_id = o.customer_id
WHERE RTRIM(o.order_status) <> 'CANCELLED'
  AND o.order_ts < current_date()
GROUP BY 1, 2, 3;
