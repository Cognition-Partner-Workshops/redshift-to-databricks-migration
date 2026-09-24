-- Nightly ETL: rebuild migration_demo.mart.daily_revenue from migration_demo.core.orders.
-- Converted from sql/etl/10_build_daily_revenue.sql (Redshift). Legacy semantics preserved:
--   * TRUNC(timestamp)            -> CAST(... AS DATE)
--   * TRUNC(GETDATE())            -> CAST(current_date() AS TIMESTAMP)  (session TZ is Etc/UTC)
--   * DECODE(...)                 -> CASE ... ELSE 'RETAIL'
--   * CHAR(10) blank-padded compare 'CANCELLED  ' -> RTRIM(order_status) <> 'CANCELLED'
--   * DECIMAL / BIGINT            -> Redshift keeps DECIMAL(38,4) and truncates toward zero,
--                                    reproduced with integer DIV on the value scaled by 10^4.
--   * DROP + CREATE TABLE ... AS  -> CREATE OR REPLACE TABLE, DISTSTYLE/SORTKEY dropped.

CREATE OR REPLACE TABLE migration_demo.mart.daily_revenue AS
SELECT
    CAST(o.order_ts AS DATE)                                        AS order_date,
    c.region,
    CASE o.sales_channel
        WHEN 'web' THEN 'ONLINE'
        WHEN 'app' THEN 'ONLINE'
        ELSE 'RETAIL'
    END                                                             AS channel_group,
    COUNT(DISTINCT o.order_id)                                      AS order_count,
    CAST(SUM(o.order_total) AS DECIMAL(38,2))                       AS gross_revenue,
    CAST(
        CAST(
            CAST(SUM(o.order_total) * 10000 AS DECIMAL(38,0))
                DIV NULLIF(COUNT(DISTINCT o.order_id), 0)
        AS DECIMAL(38,4)) / 10000
    AS DECIMAL(38,4))                                               AS avg_order_value
FROM migration_demo.core.orders o
JOIN migration_demo.core.customers c ON c.customer_id = o.customer_id
WHERE RTRIM(o.order_status) <> 'CANCELLED'
  AND o.order_ts < CAST(current_date() AS TIMESTAMP)
GROUP BY 1, 2, 3
