-- Nightly ETL (Databricks SQL): rebuild migration_demo.mart.customer_ltv.
--
-- Conversion notes (verified against live Redshift):
--   * AVG(DECIMAL(12,2)): Redshift returns NUMERIC(38,2) and TRUNCATES the
--     quotient at scale 2 on table data (verified live: 18340.88/18 =
--     1018.937... -> 1018.93). Beware probing this with literal-only
--     queries: the planner constant-folds those through a path that ROUNDS
--     (AVG of literals 0.01,0.02 -> 0.02), which is misleading. Databricks
--     AVG rounds at scale 6, so truncate explicitly; order_total >= 0, so
--     FLOOR == truncation.
--   * DATEDIFF(day, ts1, ts2): Redshift counts day-boundary crossings, i.e.
--     truncates both timestamps to dates first -> datediff(date2, date1).
--   * CHAR(10) blank-padded compare -> rtrim() (see 10_build_daily_revenue).
--   * customer_code / region stay blank-padded exactly as backfilled, so
--     row-level diffs against Redshift compare equal.
--   * DISTKEY/SORTKEY dropped.

CREATE OR REPLACE TABLE migration_demo.mart.customer_ltv AS
SELECT
    c.customer_id,
    c.customer_code,
    c.region,
    MIN(o.order_ts)                                     AS first_order_ts,
    MAX(o.order_ts)                                     AS last_order_ts,
    COUNT(o.order_id)                                   AS lifetime_orders,
    CAST(SUM(o.order_total) AS DECIMAL(38,2))           AS lifetime_revenue,
    CAST(FLOOR(SUM(o.order_total) * 100 / COUNT(o.order_id))
         / 100 AS DECIMAL(38,2))                        AS avg_order_value,
    datediff(CAST(MAX(o.order_ts) AS DATE),
             CAST(MIN(o.order_ts) AS DATE))             AS active_days
FROM migration_demo.core.customers c
JOIN migration_demo.core.orders o ON o.customer_id = c.customer_id
WHERE rtrim(o.order_status) <> 'CANCELLED'
GROUP BY c.customer_id, c.customer_code, c.region;
