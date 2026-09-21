-- Trino: DROP TABLE + CTAS into a Parquet external_location. Databricks: INSERT OVERWRITE into the Delta table declared in ddl/04_mart_tables.sql.
-- The Trino version joined lake (Hive) and ops (Postgres) across connectors; here both are Unity Catalog tables.
-- avg(order_total): Trino keeps DECIMAL(12,2) (half-up); Databricks widens to DECIMAL(16,6), so cast back.
-- sum(order_total): Trino DECIMAL(38,2); Databricks DECIMAL(22,2), cast to keep the type.
-- date_diff('day', a, b): Trino counts whole 24h periods between timestamps; datediff() counts calendar-day
-- boundaries and differs for 94 of 200 customers, so compute floor(millis / 86,400,000) instead.
-- array_agg(DISTINCT tag ORDER BY tag) -> array_sort(collect_set(tag)) (deterministic order).
-- arbitrary(region) -> any_value(region). format_datetime -> date_format (same 'yyyy-MM' pattern).
INSERT OVERWRITE trino_migration_demo.mart.customer_ltv
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
    CAST(c.customer_code AS CHAR(12)) AS customer_code,
    CAST(any_value(c.region) AS CHAR(4)) AS region,
    o.first_order_ts,
    o.last_order_ts,
    o.lifetime_orders,
    o.lifetime_revenue,
    o.avg_order_value,
    CAST(floor((unix_millis(o.last_order_ts) - unix_millis(o.first_order_ts)) / 86400000) AS BIGINT) AS active_days,
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
