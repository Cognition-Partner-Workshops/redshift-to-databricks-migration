DROP TABLE IF EXISTS lake.mart.customer_ltv;

CREATE TABLE lake.mart.customer_ltv
WITH (
    format = 'PARQUET',
    external_location = 'file:///data/warehouse/mart/customer_ltv'
)
AS
WITH order_summary AS (
    SELECT
        customer_id,
        min(order_ts) AS first_order_ts,
        max(order_ts) AS last_order_ts,
        count(order_id) AS lifetime_orders,
        sum(order_total) AS lifetime_revenue,
        avg(order_total) AS avg_order_value
    FROM lake.core.orders
    WHERE order_status <> 'CANCELLED'
    GROUP BY customer_id
),
tag_summary AS (
    SELECT
        t.customer_id,
        array_agg(DISTINCT t.tag ORDER BY t.tag) AS tags
    FROM ops.public.customer_tags t
    GROUP BY t.customer_id
)
SELECT
    c.customer_id,
    c.customer_code,
    arbitrary(c.region) AS region,
    o.first_order_ts,
    o.last_order_ts,
    o.lifetime_orders,
    o.lifetime_revenue,
    o.avg_order_value,
    date_diff('day', o.first_order_ts, o.last_order_ts) AS active_days,
    format_datetime(o.first_order_ts, 'yyyy-MM') AS first_order_month,
    coalesce(t.tags, CAST(ARRAY[] AS ARRAY(VARCHAR))) AS tags
FROM ops.public.customers c
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
