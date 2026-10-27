-- Nightly ETL: rebuild migration_demo.mart.customer_ltv.
-- Converted from sql/etl/11_build_customer_ltv.sql.
--   CHAR(10) compare      -> rtrim(): order_status keeps Redshift blank padding ('CANCELLED ')
--   AVG(DECIMAL(12,2))    -> Redshift returns DECIMAL(38,2) truncated; Databricks AVG returns
--                            DECIMAL(16,6) rounded. Reproduced with integer division on cents
--   DATEDIFF(day, ts, ts) -> datediff(date, date): Redshift counts day boundaries crossed
--   DROP + CTAS           -> CREATE OR REPLACE (atomic swap); DISTKEY / SORTKEY dropped
CREATE OR REPLACE TABLE migration_demo.mart.customer_ltv
USING DELTA
AS
SELECT
    c.customer_id,
    c.customer_code,
    c.region,
    MIN(o.order_ts)                                     AS first_order_ts,
    MAX(o.order_ts)                                     AS last_order_ts,
    COUNT(o.order_id)                                   AS lifetime_orders,
    CAST(SUM(o.order_total) AS DECIMAL(38,2))           AS lifetime_revenue,
    CAST(
        CAST(CAST(SUM(o.order_total) * 100 AS BIGINT) DIV COUNT(o.order_total)
             AS DECIMAL(38,2)) / 100
        AS DECIMAL(38,2))                               AS avg_order_value,
    CAST(datediff(CAST(MAX(o.order_ts) AS DATE), CAST(MIN(o.order_ts) AS DATE)) AS BIGINT)
                                                        AS active_days
FROM migration_demo.core.customers c
JOIN migration_demo.core.orders o ON o.customer_id = c.customer_id
WHERE rtrim(o.order_status) <> 'CANCELLED'
GROUP BY c.customer_id, c.customer_code, c.region;
