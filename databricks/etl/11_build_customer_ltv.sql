-- Nightly ETL: rebuild migration_demo.mart.customer_ltv.
-- Converted from sql/etl/11_build_customer_ltv.sql (Redshift).
--   * DROP TABLE + CREATE TABLE ... AS  -> CREATE OR REPLACE TABLE ... AS
--   * DISTKEY / SORTKEY dropped (no equivalent needed on Delta)
--   * CHAR(10) compare 'CANCELLED  ' -> RTRIM(order_status) <> 'CANCELLED'
--     (Redshift ignores trailing blanks on CHAR, Databricks STRING does not)
--   * AVG(order_total): Redshift keeps scale 2 and truncates toward zero,
--     Databricks widens and rounds, so the truncation is reproduced explicitly
--     and cast to DECIMAL(38,2) to match the legacy column type
--   * DATEDIFF(day, a, b) -> DATEDIFF(DATE(b), DATE(a)) (calendar-day crossings,
--     Databricks argument order is end, start)
--   * Result column types pinned to the Redshift types seen through federation
CREATE OR REPLACE TABLE migration_demo.mart.customer_ltv AS
SELECT
    c.customer_id,
    c.customer_code,
    c.region,
    MIN(o.order_ts)                                                     AS first_order_ts,
    MAX(o.order_ts)                                                     AS last_order_ts,
    COUNT(o.order_id)                                                   AS lifetime_orders,
    CAST(SUM(o.order_total) AS DECIMAL(38,2))                           AS lifetime_revenue,
    CAST(
        (SIGN(SUM(o.order_total))
         * FLOOR(ABS(SUM(o.order_total)) * 100 / COUNT(o.order_total)))
        / 100
        AS DECIMAL(38,2))                                               AS avg_order_value,
    CAST(DATEDIFF(CAST(MAX(o.order_ts) AS DATE), CAST(MIN(o.order_ts) AS DATE)) AS BIGINT)
                                                                        AS active_days
FROM migration_demo.core.customers c
JOIN migration_demo.core.orders o ON o.customer_id = c.customer_id
WHERE RTRIM(o.order_status) <> 'CANCELLED'
GROUP BY c.customer_id, c.customer_code, c.region
