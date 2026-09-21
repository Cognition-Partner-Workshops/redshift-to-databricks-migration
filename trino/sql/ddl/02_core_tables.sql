CREATE TABLE IF NOT EXISTS lake.core.orders (
    order_id      BIGINT,
    customer_id   INTEGER,
    order_ts      TIMESTAMP(3),
    order_status  VARCHAR,
    order_total   DECIMAL(12, 2),
    sales_channel VARCHAR,
    attrs         MAP(VARCHAR, VARCHAR),
    order_date    DATE
)
WITH (
    format = 'PARQUET',
    partitioned_by = ARRAY['order_date']
);

CREATE TABLE IF NOT EXISTS lake.core.order_items (
    order_item_id BIGINT,
    order_id      BIGINT,
    sku           VARCHAR,
    quantity      SMALLINT,
    unit_price    DECIMAL(10, 2),
    discount_pct  DECIMAL(5, 4)
)
WITH (format = 'PARQUET');
