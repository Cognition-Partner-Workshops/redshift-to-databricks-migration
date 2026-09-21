CREATE SCHEMA IF NOT EXISTS trino_migration_demo.core;
CREATE SCHEMA IF NOT EXISTS trino_migration_demo.ops;

CREATE OR REPLACE TABLE trino_migration_demo.core.orders
USING DELTA
PARTITIONED BY (order_date)
AS
SELECT
    order_id,
    customer_id,
    order_ts,
    order_status,
    order_total,
    sales_channel,
    attrs,
    order_date
FROM trino_migration_demo.trino_src.core_orders;

CREATE OR REPLACE TABLE trino_migration_demo.core.order_items
USING DELTA
AS
SELECT
    order_item_id,
    order_id,
    sku,
    quantity,
    unit_price,
    discount_pct
FROM trino_migration_demo.trino_src.core_order_items;

CREATE OR REPLACE TABLE trino_migration_demo.ops.customers
USING DELTA
AS
SELECT
    customer_id,
    customer_code,
    full_name,
    email,
    CAST(region AS CHAR(4)) AS region,
    signup_date,
    is_active,
    created_at
FROM trino_migration_demo.trino_src.ops_customers;

CREATE OR REPLACE TABLE trino_migration_demo.ops.customer_tags
USING DELTA
AS
SELECT customer_id, tag
FROM trino_migration_demo.trino_src.ops_customer_tags;
