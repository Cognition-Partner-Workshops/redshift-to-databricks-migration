-- Silver load: append the orders that arrived since the last run.
--
-- core.orders and core.customers are append-only and order_id is a monotonically
-- increasing identity, so a row's enriched form never changes once written and a
-- high-water mark on order_id is an exact incremental load. Running this twice
-- adds nothing. To rebuild from scratch: TRUNCATE TABLE migration_demo.silver.enriched_orders
-- and run again.
--
-- Translated from the join + filter duplicated in sql/etl/10_* and sql/etl/11_*:
--   TRUNC(order_ts)                  -> to_date(order_ts)
--   DECODE(sales_channel, ...)       -> CASE WHEN
--   order_status <> 'CANCELLED  '    -> trim(order_status) <> 'CANCELLED'
--                                      (CHAR(10) blank padding does not exist in STRING)
--   GETDATE()                        -> current_timestamp()

INSERT INTO migration_demo.silver.enriched_orders
    (order_id, customer_id, customer_code, region, order_ts, order_date,
     order_status, sales_channel, channel_group, order_total, enriched_at)
SELECT
    o.order_id,
    o.customer_id,
    c.customer_code,
    c.region,
    o.order_ts,
    to_date(o.order_ts)                                 AS order_date,
    trim(o.order_status)                                AS order_status,
    o.sales_channel,
    CASE WHEN o.sales_channel IN ('web', 'app') THEN 'ONLINE'
         ELSE 'RETAIL'
    END                                                 AS channel_group,
    o.order_total,
    current_timestamp()                                 AS enriched_at
FROM migration_demo.core.orders o
JOIN migration_demo.core.customers c ON c.customer_id = o.customer_id
WHERE trim(o.order_status) <> 'CANCELLED'
  AND o.order_id > (SELECT COALESCE(MAX(order_id), 0) FROM migration_demo.silver.enriched_orders);
