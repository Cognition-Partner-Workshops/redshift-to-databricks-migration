-- Populate the migrated core/ops tables from the raw snapshot (full refresh).
INSERT OVERWRITE trino_migration_demo.core.orders
SELECT order_id, customer_id, order_ts, order_status, order_total, sales_channel, attrs, order_date
FROM trino_migration_demo.trino_src.core_orders;

INSERT OVERWRITE trino_migration_demo.core.order_items
SELECT order_item_id, order_id, sku, quantity, unit_price, discount_pct
FROM trino_migration_demo.trino_src.core_order_items;

INSERT OVERWRITE trino_migration_demo.ops.customers
SELECT customer_id, customer_code, full_name, email, region, signup_date, is_active, created_at
FROM trino_migration_demo.trino_src.ops_customers;

INSERT OVERWRITE trino_migration_demo.ops.customer_tags
SELECT customer_id, tag
FROM trino_migration_demo.trino_src.ops_customer_tags;
