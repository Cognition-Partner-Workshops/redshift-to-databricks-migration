-- Converted from trino/sql/etl/11_build_customer_ltv.sql
-- Conversion notes:
--   avg(DECIMAL(12,2))                 -> Trino keeps the input scale, Databricks widens to
--                                         (16,6), so the result is cast back to DECIMAL(12,2)
--   sum(DECIMAL(12,2))                 -> cast back to DECIMAL(38,2)
--   array_agg(DISTINCT tag ORDER BY t) -> array_sort(collect_set(tag))
--   arbitrary(region)                  -> any_value(region)
--   date_diff('day', a, b)             -> timestampdiff(DAY, a, b), which truncates to
--       whole elapsed days the way Trino does. Spark's datediff() counts calendar-date
--       boundaries instead and is one higher whenever the later timestamp's time-of-day
--       precedes the earlier one's (97 of 150 rows here). timestampdiff keeps wall-clock
--       arithmetic on TIMESTAMP_NTZ, so a DST transition inside the interval cannot add
--       or drop an hour the way an epoch-microsecond subtraction would.
--   format_datetime(ts, 'yyyy-MM')     -> date_format(ts, 'yyyy-MM')
--   CAST(ARRAY[] AS ARRAY(VARCHAR))    -> CAST(array() AS ARRAY<STRING>)
-- The table is declared before the insert so customer_code/region keep CHAR types - a
-- CTAS would widen them to STRING.
CREATE OR REPLACE TABLE trino_migration_demo_run4.mart.customer_ltv (
    customer_id       INT,
    customer_code     CHAR(12),
    region            CHAR(4),
    first_order_ts    TIMESTAMP_NTZ,
    last_order_ts     TIMESTAMP_NTZ,
    lifetime_orders   BIGINT,
    lifetime_revenue  DECIMAL(38, 2),
    avg_order_value   DECIMAL(12, 2),
    active_days       BIGINT,
    first_order_month STRING,
    tags              ARRAY<STRING>
) TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported');

INSERT INTO trino_migration_demo_run4.mart.customer_ltv
WITH order_summary AS (
    SELECT
        customer_id,
        min(order_ts)                                          AS first_order_ts,
        max(order_ts)                                          AS last_order_ts,
        count(order_id)                                        AS lifetime_orders,
        CAST(sum(order_total) AS DECIMAL(38, 2))               AS lifetime_revenue,
        CAST(avg(order_total) AS DECIMAL(12, 2))               AS avg_order_value
    FROM trino_migration_demo_run4.core.orders
    WHERE order_status <> 'CANCELLED'
    GROUP BY customer_id
),
tag_summary AS (
    SELECT
        t.customer_id,
        array_sort(collect_set(t.tag)) AS tags
    FROM trino_migration_demo_run4.ops.customer_tags t
    GROUP BY t.customer_id
)
SELECT
    c.customer_id,
    c.customer_code,
    any_value(c.region)                                        AS region,
    o.first_order_ts,
    o.last_order_ts,
    o.lifetime_orders,
    o.lifetime_revenue,
    o.avg_order_value,
    CAST(timestampdiff(DAY, o.first_order_ts, o.last_order_ts) AS BIGINT) AS active_days,
    date_format(o.first_order_ts, 'yyyy-MM')                   AS first_order_month,
    coalesce(t.tags, CAST(array() AS ARRAY<STRING>))           AS tags
FROM trino_migration_demo_run4.ops.customers c
JOIN order_summary o ON o.customer_id = c.customer_id
LEFT JOIN tag_summary t ON t.customer_id = c.customer_id
GROUP BY
    c.customer_id,
    c.customer_code,
    o.first_order_ts,
    o.last_order_ts,
    o.lifetime_orders,
    o.lifetime_revenue,
    o.avg_order_value,
    t.tags
