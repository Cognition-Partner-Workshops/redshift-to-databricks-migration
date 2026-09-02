-- Nightly ETL: rebuild migration_demo.mart.daily_revenue from migration_demo.core.orders.
-- Converted from sql/etl/10_build_daily_revenue.sql (Redshift).
--   TRUNC(ts)            -> CAST(ts AS DATE)
--   DECODE(...)          -> CASE
--   TRUNC(GETDATE())     -> current_date()   (warehouse session timezone is UTC, as in Redshift)
--   DISTSTYLE/SORTKEY    -> dropped (Delta); DROP + CREATE -> CREATE OR REPLACE
-- Result columns are cast to the exact Redshift output types (NUMERIC(38,2) / NUMERIC(38,4)).
-- Redshift DECIMAL division truncates toward zero at the result scale (4); Databricks CAST rounds,
-- so the quotient is truncated explicitly (FLOOR for non-negative, CEIL for negative).

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
WHERE RTRIM(o.order_status) <> 'CANCELLED'               -- CHAR(10): Redshift ignores trailing blanks, Delta STRING does not
  AND o.order_ts < current_date()
GROUP BY 1, 2, 3;
