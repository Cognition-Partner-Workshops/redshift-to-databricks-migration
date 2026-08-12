-- Scheduler entrypoint (Databricks SQL) replacing mart.sp_refresh_marts().
--
-- The Redshift original is a plpgsql stored procedure that RAISE INFOs a
-- start/finish message and (in the real estate) inlines the mart builds; in
-- this demo the builds live in 10_/11_ and are run in order. On Databricks
-- the scheduler equivalent is a Databricks Job (or SQL task) that runs the
-- two build scripts in order on the SQL warehouse. This script is that
-- inlined nightly refresh; the RAISE INFO logging is replaced by the job
-- run's own logging.

-- refresh started
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
-- refresh finished
