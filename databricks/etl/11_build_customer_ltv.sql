-- Nightly ETL: rebuild mart.customer_ltv.
-- Converted from Redshift (sql/etl/11_build_customer_ltv.sql):
--   DATEDIFF(day, a, b) -> datediff(b, a)
--   CHAR(10) blank-padded status comparison -> rtrim() on the migrated STRING column
--   DISTKEY/SORTKEY     -> not applicable on Delta (dropped)
--   AVG(DECIMAL)        -> Redshift truncates the result toward zero at the
--                          argument's scale (2), while Databricks rounds.
--                          sign(x) * floor(abs(x), 2) reproduces the
--                          toward-zero truncation for any sign.

CREATE OR REPLACE TABLE migration_demo.mart.customer_ltv AS
SELECT
    c.customer_id,
    c.customer_code,
    c.region,
    MIN(o.order_ts)                                     AS first_order_ts,
    MAX(o.order_ts)                                     AS last_order_ts,
    COUNT(o.order_id)                                   AS lifetime_orders,
    CAST(SUM(o.order_total) AS DECIMAL(38,2))           AS lifetime_revenue,
    CAST(SIGN(AVG(o.order_total)) * FLOOR(ABS(AVG(o.order_total)), 2)
         AS DECIMAL(38,2))                              AS avg_order_value,
    DATEDIFF(MAX(o.order_ts), MIN(o.order_ts))          AS active_days
FROM migration_demo.core.customers c
JOIN migration_demo.core.orders o ON o.customer_id = c.customer_id
WHERE RTRIM(o.order_status) <> 'CANCELLED'
GROUP BY c.customer_id, c.customer_code, c.region;
