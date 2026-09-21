DROP TABLE IF EXISTS lake.mart.daily_revenue;

CREATE TABLE lake.mart.daily_revenue
WITH (
    format = 'PARQUET',
    external_location = 'file:///data/warehouse/mart/daily_revenue'
)
AS
SELECT
    date_trunc('day', o.order_ts) AS order_date,
    c.region,
    if(element_at(o.attrs, 'promo') = 'NONE', 'ORGANIC', 'PROMOTIONAL') AS promo_group,
    approx_distinct(o.order_id) AS order_count,
    SUM(try_cast(o.order_total AS DECIMAL(12, 2))) AS gross_revenue,
    SUM(try_cast(o.order_total AS DECIMAL(12, 2)))
        / NULLIF(approx_distinct(o.order_id), 0) AS avg_order_value
FROM lake.core.orders o
JOIN ops.public.customers c ON c.customer_id = o.customer_id
WHERE o.order_status <> 'CANCELLED'
  AND o.order_ts < date_trunc('day', current_timestamp)
GROUP BY 1, 2, 3;
