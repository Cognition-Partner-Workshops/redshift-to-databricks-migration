CREATE TABLE IF NOT EXISTS trino_migration_demo.core.orders (
    order_id BIGINT,
    customer_id INT,
    order_ts TIMESTAMP,
    order_status STRING,
    order_total DECIMAL(12, 2),
    sales_channel STRING,
    attrs MAP<STRING, STRING>,
    order_date DATE
)
USING DELTA
PARTITIONED BY (order_date);

CREATE TABLE IF NOT EXISTS trino_migration_demo.core.order_items (
    order_item_id BIGINT,
    order_id BIGINT,
    sku STRING,
    quantity SMALLINT,
    unit_price DECIMAL(10, 2),
    discount_pct DECIMAL(5, 4)
)
USING DELTA;
