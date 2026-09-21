CREATE OR REPLACE TABLE trino_migration_demo.mart.customer_ltv
USING DELTA
AS
WITH order_summary AS (
    SELECT
        customer_id,
        MIN(order_ts) AS first_order_ts,
        MAX(order_ts) AS last_order_ts,
        COUNT(order_id) AS lifetime_orders,
        SUM(order_total) AS lifetime_revenue,
        CAST(AVG(order_total) AS DECIMAL(12, 2)) AS avg_order_value
    FROM trino_migration_demo.core.orders
    WHERE order_status <> 'CANCELLED'
    GROUP BY customer_id
),
tag_summary AS (
    SELECT
        t.customer_id,
        ARRAY_SORT(COLLECT_SET(t.tag)) AS tags
    FROM trino_migration_demo.ops.customer_tags t
    GROUP BY t.customer_id
)
SELECT
    c.customer_id,
    c.customer_code,
    ANY_VALUE(c.region) AS region,
    o.first_order_ts,
    o.last_order_ts,
    o.lifetime_orders,
    o.lifetime_revenue,
    o.avg_order_value,
    (UNIX_MILLIS(o.last_order_ts) - UNIX_MILLIS(o.first_order_ts)) DIV 86400000 AS active_days,
    DATE_FORMAT(o.first_order_ts, 'yyyy-MM') AS first_order_month,
    COALESCE(t.tags, CAST(ARRAY() AS ARRAY<STRING>)) AS tags
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
