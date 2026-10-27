-- Nightly ETL: rebuild migration_demo.mart.daily_revenue from core.orders.
-- Converted from sql/etl/10_build_daily_revenue.sql.
--   TRUNC(ts)            -> CAST(ts AS DATE)
--   TRUNC(GETDATE())     -> current_date() (warehouse session time zone is UTC, same as Redshift)
--   DECODE               -> CASE
--   CHAR(10) compare     -> rtrim(): order_status keeps Redshift blank padding ('CANCELLED ')
--   avg_order_value      -> Redshift DECIMAL / BIGINT truncates to DECIMAL(38,4); reproduced with
--                           integer division on ten-thousandths
--   DROP + CTAS          -> CREATE OR REPLACE (atomic swap); DISTSTYLE / SORTKEY dropped
CREATE OR REPLACE TABLE migration_demo.mart.daily_revenue
USING DELTA
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
    CAST(
        CAST(CAST(SUM(o.order_total) * 10000 AS BIGINT) DIV NULLIF(COUNT(DISTINCT o.order_id), 0)
             AS DECIMAL(38,4)) / 10000
        AS DECIMAL(38,4))                               AS avg_order_value
FROM migration_demo.core.orders o
JOIN migration_demo.core.customers c ON c.customer_id = o.customer_id
WHERE rtrim(o.order_status) <> 'CANCELLED'
  AND o.order_ts < CAST(current_date() AS TIMESTAMP)
GROUP BY 1, 2, 3;
