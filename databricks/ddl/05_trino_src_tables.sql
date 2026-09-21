-- Raw snapshot of the six Trino tables with the Trino column types (CHAR/VARCHAR kept, which CTAS would not do).
CREATE TABLE IF NOT EXISTS trino_migration_demo.trino_src.core_orders (
    order_id BIGINT, customer_id INT, order_ts TIMESTAMP, order_status STRING, order_total DECIMAL(12, 2),
    sales_channel STRING, attrs MAP<STRING, STRING>, order_date DATE
);
CREATE TABLE IF NOT EXISTS trino_migration_demo.trino_src.core_order_items (
    order_item_id BIGINT, order_id BIGINT, sku STRING, quantity SMALLINT, unit_price DECIMAL(10, 2), discount_pct DECIMAL(5, 4)
);
CREATE TABLE IF NOT EXISTS trino_migration_demo.trino_src.ops_customers (
    customer_id INT, customer_code CHAR(12), full_name VARCHAR(120), email VARCHAR(160), region CHAR(4),
    signup_date DATE, is_active BOOLEAN, created_at TIMESTAMP
);
CREATE TABLE IF NOT EXISTS trino_migration_demo.trino_src.ops_customer_tags (
    customer_id INT, tag STRING
);
CREATE TABLE IF NOT EXISTS trino_migration_demo.trino_src.mart_daily_revenue (
    order_date TIMESTAMP, region CHAR(4), promo_group VARCHAR(11), order_count BIGINT,
    gross_revenue DECIMAL(38, 2), avg_order_value DECIMAL(38, 6)
);
CREATE TABLE IF NOT EXISTS trino_migration_demo.trino_src.mart_customer_ltv (
    customer_id INT, customer_code CHAR(12), region CHAR(4), first_order_ts TIMESTAMP, last_order_ts TIMESTAMP,
    lifetime_orders BIGINT, lifetime_revenue DECIMAL(38, 2), avg_order_value DECIMAL(12, 2), active_days BIGINT,
    first_order_month STRING, tags ARRAY<STRING>
);
