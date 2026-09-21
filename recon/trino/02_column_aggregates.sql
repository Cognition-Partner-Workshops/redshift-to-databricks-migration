-- Per-column aggregates of the rebuilt marts vs the Trino snapshot marts. One row per column, diff must be 0.
-- Numeric columns: SUM to full scale. Timestamps: SUM of epoch millis. Strings/arrays: count distinct + sum of hash.
WITH dr AS (
    SELECT 'daily_revenue' AS mart, 'order_date' AS col, CAST(sum(unix_millis(order_date)) AS DECIMAL(38, 6)) AS v, 'databricks' AS side FROM trino_migration_demo.mart.daily_revenue
    UNION ALL SELECT 'daily_revenue', 'order_date', CAST(sum(unix_millis(order_date)) AS DECIMAL(38, 6)), 'trino' FROM trino_migration_demo.trino_src.mart_daily_revenue
    UNION ALL SELECT 'daily_revenue', 'region', CAST(sum(hash(region)) AS DECIMAL(38, 6)), 'databricks' FROM trino_migration_demo.mart.daily_revenue
    UNION ALL SELECT 'daily_revenue', 'region', CAST(sum(hash(region)) AS DECIMAL(38, 6)), 'trino' FROM trino_migration_demo.trino_src.mart_daily_revenue
    UNION ALL SELECT 'daily_revenue', 'promo_group', CAST(sum(hash(promo_group)) AS DECIMAL(38, 6)), 'databricks' FROM trino_migration_demo.mart.daily_revenue
    UNION ALL SELECT 'daily_revenue', 'promo_group', CAST(sum(hash(promo_group)) AS DECIMAL(38, 6)), 'trino' FROM trino_migration_demo.trino_src.mart_daily_revenue
    UNION ALL SELECT 'daily_revenue', 'order_count', CAST(sum(order_count) AS DECIMAL(38, 6)), 'databricks' FROM trino_migration_demo.mart.daily_revenue
    UNION ALL SELECT 'daily_revenue', 'order_count', CAST(sum(order_count) AS DECIMAL(38, 6)), 'trino' FROM trino_migration_demo.trino_src.mart_daily_revenue
    UNION ALL SELECT 'daily_revenue', 'gross_revenue', CAST(sum(gross_revenue) AS DECIMAL(38, 6)), 'databricks' FROM trino_migration_demo.mart.daily_revenue
    UNION ALL SELECT 'daily_revenue', 'gross_revenue', CAST(sum(gross_revenue) AS DECIMAL(38, 6)), 'trino' FROM trino_migration_demo.trino_src.mart_daily_revenue
    UNION ALL SELECT 'daily_revenue', 'avg_order_value', CAST(sum(avg_order_value) AS DECIMAL(38, 6)), 'databricks' FROM trino_migration_demo.mart.daily_revenue
    UNION ALL SELECT 'daily_revenue', 'avg_order_value', CAST(sum(avg_order_value) AS DECIMAL(38, 6)), 'trino' FROM trino_migration_demo.trino_src.mart_daily_revenue
),
ltv AS (
    SELECT 'customer_ltv' AS mart, 'customer_id' AS col, CAST(sum(customer_id) AS DECIMAL(38, 6)) AS v, 'databricks' AS side FROM trino_migration_demo.mart.customer_ltv
    UNION ALL SELECT 'customer_ltv', 'customer_id', CAST(sum(customer_id) AS DECIMAL(38, 6)), 'trino' FROM trino_migration_demo.trino_src.mart_customer_ltv
    UNION ALL SELECT 'customer_ltv', 'customer_code', CAST(sum(hash(customer_code)) AS DECIMAL(38, 6)), 'databricks' FROM trino_migration_demo.mart.customer_ltv
    UNION ALL SELECT 'customer_ltv', 'customer_code', CAST(sum(hash(customer_code)) AS DECIMAL(38, 6)), 'trino' FROM trino_migration_demo.trino_src.mart_customer_ltv
    UNION ALL SELECT 'customer_ltv', 'region', CAST(sum(hash(region)) AS DECIMAL(38, 6)), 'databricks' FROM trino_migration_demo.mart.customer_ltv
    UNION ALL SELECT 'customer_ltv', 'region', CAST(sum(hash(region)) AS DECIMAL(38, 6)), 'trino' FROM trino_migration_demo.trino_src.mart_customer_ltv
    UNION ALL SELECT 'customer_ltv', 'first_order_ts', CAST(sum(unix_millis(first_order_ts)) AS DECIMAL(38, 6)), 'databricks' FROM trino_migration_demo.mart.customer_ltv
    UNION ALL SELECT 'customer_ltv', 'first_order_ts', CAST(sum(unix_millis(first_order_ts)) AS DECIMAL(38, 6)), 'trino' FROM trino_migration_demo.trino_src.mart_customer_ltv
    UNION ALL SELECT 'customer_ltv', 'last_order_ts', CAST(sum(unix_millis(last_order_ts)) AS DECIMAL(38, 6)), 'databricks' FROM trino_migration_demo.mart.customer_ltv
    UNION ALL SELECT 'customer_ltv', 'last_order_ts', CAST(sum(unix_millis(last_order_ts)) AS DECIMAL(38, 6)), 'trino' FROM trino_migration_demo.trino_src.mart_customer_ltv
    UNION ALL SELECT 'customer_ltv', 'lifetime_orders', CAST(sum(lifetime_orders) AS DECIMAL(38, 6)), 'databricks' FROM trino_migration_demo.mart.customer_ltv
    UNION ALL SELECT 'customer_ltv', 'lifetime_orders', CAST(sum(lifetime_orders) AS DECIMAL(38, 6)), 'trino' FROM trino_migration_demo.trino_src.mart_customer_ltv
    UNION ALL SELECT 'customer_ltv', 'lifetime_revenue', CAST(sum(lifetime_revenue) AS DECIMAL(38, 6)), 'databricks' FROM trino_migration_demo.mart.customer_ltv
    UNION ALL SELECT 'customer_ltv', 'lifetime_revenue', CAST(sum(lifetime_revenue) AS DECIMAL(38, 6)), 'trino' FROM trino_migration_demo.trino_src.mart_customer_ltv
    UNION ALL SELECT 'customer_ltv', 'avg_order_value', CAST(sum(avg_order_value) AS DECIMAL(38, 6)), 'databricks' FROM trino_migration_demo.mart.customer_ltv
    UNION ALL SELECT 'customer_ltv', 'avg_order_value', CAST(sum(avg_order_value) AS DECIMAL(38, 6)), 'trino' FROM trino_migration_demo.trino_src.mart_customer_ltv
    UNION ALL SELECT 'customer_ltv', 'active_days', CAST(sum(active_days) AS DECIMAL(38, 6)), 'databricks' FROM trino_migration_demo.mart.customer_ltv
    UNION ALL SELECT 'customer_ltv', 'active_days', CAST(sum(active_days) AS DECIMAL(38, 6)), 'trino' FROM trino_migration_demo.trino_src.mart_customer_ltv
    UNION ALL SELECT 'customer_ltv', 'first_order_month', CAST(sum(hash(first_order_month)) AS DECIMAL(38, 6)), 'databricks' FROM trino_migration_demo.mart.customer_ltv
    UNION ALL SELECT 'customer_ltv', 'first_order_month', CAST(sum(hash(first_order_month)) AS DECIMAL(38, 6)), 'trino' FROM trino_migration_demo.trino_src.mart_customer_ltv
    UNION ALL SELECT 'customer_ltv', 'tags', CAST(sum(hash(to_json(tags))) AS DECIMAL(38, 6)), 'databricks' FROM trino_migration_demo.mart.customer_ltv
    UNION ALL SELECT 'customer_ltv', 'tags', CAST(sum(hash(to_json(tags))) AS DECIMAL(38, 6)), 'trino' FROM trino_migration_demo.trino_src.mart_customer_ltv
),
u AS (SELECT * FROM dr UNION ALL SELECT * FROM ltv)
SELECT
    mart, col,
    max(if(side = 'databricks', v, NULL)) AS databricks_value,
    max(if(side = 'trino', v, NULL))      AS trino_value,
    max(if(side = 'databricks', v, NULL)) - max(if(side = 'trino', v, NULL)) AS diff
FROM u
GROUP BY mart, col
ORDER BY mart, col;
