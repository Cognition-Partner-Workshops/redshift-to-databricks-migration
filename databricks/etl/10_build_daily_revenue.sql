-- Trino: DROP TABLE + CTAS into a Parquet external_location. Databricks: INSERT OVERWRITE into the Delta table declared in ddl/04_mart_tables.sql (atomic, versioned).
-- approx_distinct(order_id) -> COUNT(DISTINCT order_id): exact instead of HLL; verified equal on the Trino snapshot.
-- element_at(attrs,'promo') -> try_element_at (element_at on a missing key raises under ANSI).
-- try_cast(order_total AS DECIMAL(12,2)) dropped: order_total already is DECIMAL(12,2); casting SUM to DECIMAL(38,2)
-- before dividing by the BIGINT count reproduces Trino's DECIMAL(38,6) result type and half-up rounding.
INSERT OVERWRITE trino_migration_demo.mart.daily_revenue
SELECT
    date_trunc('day', o.order_ts) AS order_date,
    CAST(c.region AS CHAR(4)) AS region,
    CAST(if(try_element_at(o.attrs, 'promo') = 'NONE', 'ORGANIC', 'PROMOTIONAL') AS VARCHAR(11)) AS promo_group,
    COUNT(DISTINCT o.order_id) AS order_count,
    CAST(SUM(o.order_total) AS DECIMAL(38, 2)) AS gross_revenue,
    CAST(
        CAST(SUM(o.order_total) AS DECIMAL(38, 2))
            / NULLIF(COUNT(DISTINCT o.order_id), 0)
        AS DECIMAL(38, 6)) AS avg_order_value
FROM trino_migration_demo.core.orders o
JOIN trino_migration_demo.ops.customers c ON c.customer_id = o.customer_id
WHERE o.order_status <> 'CANCELLED'
  AND o.order_ts < date_trunc('day', current_timestamp())
GROUP BY 1, 2, 3;
