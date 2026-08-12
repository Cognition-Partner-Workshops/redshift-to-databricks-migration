-- Nightly ETL (Databricks SQL): rebuild migration_demo.mart.daily_revenue
-- from migration_demo.core.orders.
--
-- Conversion notes (verified against live Redshift):
--   * TRUNC(timestamp)            -> CAST(ts AS DATE)
--   * GETDATE() / TRUNC(GETDATE())-> current_timestamp() / current_date()
--   * DECODE(...)                 -> CASE (DECODE's NULL=NULL match is
--                                    irrelevant here: NULL falls to the
--                                    default in both engines)
--   * CHAR(10) blank-padded compare: Redshift ignores trailing blanks on
--     CHAR comparisons; the backfilled column is a blank-padded STRING, so
--     compare on rtrim().
--   * SUM(DECIMAL(12,2)) / COUNT(DISTINCT ...): Redshift produces
--     NUMERIC(38,4) and TRUNCATES the quotient at scale 4 (verified:
--     23586.10/24 -> 982.7541, not .7542). Databricks decimal division
--     rounds, so truncate explicitly. order_total >= 0, so FLOOR == trunc.
--   * DISTSTYLE/SORTKEY dropped (physical layout hints, no Delta equivalent).

CREATE OR REPLACE TABLE migration_demo.mart.daily_revenue AS
SELECT
    CAST(o.order_ts AS DATE)                            AS order_date,
    c.region,
    CASE WHEN o.sales_channel = 'web' THEN 'ONLINE'
         WHEN o.sales_channel = 'app' THEN 'ONLINE'
         ELSE 'RETAIL' END                              AS channel_group,
    COUNT(DISTINCT o.order_id)                          AS order_count,
    CAST(SUM(o.order_total) AS DECIMAL(38,2))           AS gross_revenue,
    CAST(FLOOR(SUM(o.order_total) * 10000 / NULLIF(COUNT(DISTINCT o.order_id), 0))
         / 10000 AS DECIMAL(38,4))                      AS avg_order_value
FROM migration_demo.core.orders o
JOIN migration_demo.core.customers c ON c.customer_id = o.customer_id
WHERE rtrim(o.order_status) <> 'CANCELLED'
  AND o.order_ts < current_date()
GROUP BY 1, 2, 3;
