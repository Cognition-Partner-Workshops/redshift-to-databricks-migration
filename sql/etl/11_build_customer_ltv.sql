-- Nightly ETL: rebuild mart.customer_ltv.
-- NOTE: AVG over DECIMAL — Redshift *truncates* the result scale; engines that
-- round will diverge by a cent on roughly half of all customers. This is the
-- semantic trap this estate is designed to exercise.

DROP TABLE IF EXISTS mart.customer_ltv;

CREATE TABLE mart.customer_ltv
DISTKEY (customer_id)
SORTKEY (customer_id)
AS
SELECT
    c.customer_id,
    c.customer_code,
    c.region,
    MIN(o.order_ts)                          AS first_order_ts,
    MAX(o.order_ts)                          AS last_order_ts,
    COUNT(o.order_id)                        AS lifetime_orders,
    SUM(o.order_total)                       AS lifetime_revenue,
    AVG(o.order_total)                       AS avg_order_value,   -- truncated scale
    DATEDIFF(day, MIN(o.order_ts), MAX(o.order_ts)) AS active_days
FROM core.customers c
JOIN core.orders o ON o.customer_id = c.customer_id
WHERE o.order_status <> 'CANCELLED  '
GROUP BY c.customer_id, c.customer_code, c.region;
