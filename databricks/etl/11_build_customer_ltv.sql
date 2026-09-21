-- Converted from trino/sql/etl/11_build_customer_ltv.sql
-- date_diff('day', a, b) in Trino is whole elapsed 24h periods, not calendar-day boundaries.
-- array_agg(DISTINCT tag ORDER BY tag) -> array_sort(collect_set(tag)).
-- Trino avg(DECIMAL(12,2)) stays DECIMAL(12,2) (half-up), sum stays DECIMAL(38,2).
CREATE OR REPLACE TABLE trino_migration_demo.mart.customer_ltv
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS
WITH order_summary AS (
    SELECT
        customer_id,
        min(order_ts) AS first_order_ts,
        max(order_ts) AS last_order_ts,
        count(order_id) AS lifetime_orders,
        CAST(sum(order_total) AS DECIMAL(38, 2)) AS lifetime_revenue,
        CAST(avg(order_total) AS DECIMAL(12, 2)) AS avg_order_value
    FROM trino_migration_demo.core.orders
    WHERE order_status <> 'CANCELLED'
    GROUP BY customer_id
),
tag_summary AS (
    SELECT
        t.customer_id,
        array_sort(collect_set(t.tag)) AS tags
    FROM trino_migration_demo.ops.customer_tags t
    GROUP BY t.customer_id
)
SELECT
    c.customer_id,
    c.customer_code,
    any_value(c.region) AS region,
    o.first_order_ts,
    o.last_order_ts,
    o.lifetime_orders,
    o.lifetime_revenue,
    o.avg_order_value,
    (unix_millis(CAST(o.last_order_ts AS TIMESTAMP))
        - unix_millis(CAST(o.first_order_ts AS TIMESTAMP))) DIV 86400000 AS active_days,
    date_format(o.first_order_ts, 'yyyy-MM') AS first_order_month,
    coalesce(t.tags, CAST(array() AS ARRAY<STRING>)) AS tags
FROM trino_migration_demo.ops.customers c
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
    t.tags;
