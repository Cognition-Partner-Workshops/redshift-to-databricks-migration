-- Nightly ETL: rebuild mart.daily_revenue from core.orders.
-- Converted from Redshift (sql/etl/10_build_daily_revenue.sql):
--   TRUNC(timestamp)      -> CAST(... AS DATE)
--   GETDATE()             -> current_timestamp / current_date
--   DECODE(...)           -> CASE
--   CHAR(10) blank-padded status comparison -> rtrim() on the migrated STRING column
--   DISTSTYLE/SORTKEY     -> not applicable on Delta (dropped)

CREATE OR REPLACE TABLE migration_demo.mart.daily_revenue AS
SELECT
    CAST(o.order_ts AS DATE)                            AS order_date,
    c.region,
    CASE WHEN o.sales_channel IN ('web', 'app') THEN 'ONLINE'
         ELSE 'RETAIL' END                              AS channel_group,
    COUNT(DISTINCT o.order_id)                          AS order_count,
    CAST(SUM(o.order_total) AS DECIMAL(38,2))           AS gross_revenue,
    CAST(SUM(o.order_total) / NULLIF(COUNT(DISTINCT o.order_id), 0)
         AS DECIMAL(38,4))                              AS avg_order_value
FROM migration_demo.core.orders o
JOIN migration_demo.core.customers c ON c.customer_id = o.customer_id
WHERE RTRIM(o.order_status) <> 'CANCELLED'
  AND o.order_ts < CAST(current_date() AS TIMESTAMP)
GROUP BY 1, 2, 3;
