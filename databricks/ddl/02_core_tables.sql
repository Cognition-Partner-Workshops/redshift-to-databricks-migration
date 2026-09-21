CREATE TABLE IF NOT EXISTS trino_migration_demo.core.orders (
    order_id      BIGINT,
    customer_id   INT,
    order_ts      TIMESTAMP_NTZ,
    order_status  STRING,
    order_total   DECIMAL(12, 2),
    sales_channel STRING,
    attrs         MAP<STRING, STRING>,
    order_date    DATE
)
PARTITIONED BY (order_date)
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported');

CREATE TABLE IF NOT EXISTS trino_migration_demo.core.order_items (
    order_item_id BIGINT,
    order_id      BIGINT,
    sku           STRING,
    quantity      SMALLINT,
    unit_price    DECIMAL(10, 2),
    discount_pct  DECIMAL(5, 4)
);

CREATE TABLE IF NOT EXISTS trino_migration_demo.ops.customers (
    customer_id   INT NOT NULL,
    customer_code CHAR(12) NOT NULL,
    full_name     STRING NOT NULL,
    email         STRING NOT NULL,
    region        CHAR(4) NOT NULL,
    signup_date   DATE NOT NULL,
    is_active     BOOLEAN NOT NULL,
    created_at    TIMESTAMP_NTZ NOT NULL
)
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported');

CREATE TABLE IF NOT EXISTS trino_migration_demo.ops.customer_tags (
    customer_id INT NOT NULL,
    tag         STRING NOT NULL
);
