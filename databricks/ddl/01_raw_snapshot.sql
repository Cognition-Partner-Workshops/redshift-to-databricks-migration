-- Raw, untyped snapshot of the six Trino source tables, exactly as exported to CSV.
-- Every column is STRING so the landing step cannot silently coerce a value.
-- MAP and ARRAY columns were exported as JSON text by the Trino side.
CREATE OR REPLACE TABLE trino_migration_demo_run4.trino_src.orders_raw AS
SELECT * FROM read_files(
  '/Volumes/trino_migration_demo_run4/trino_src/landing/orders.csv',
  format => 'csv', header => true, escape => '"',
  schema => 'order_id STRING, customer_id STRING, order_ts STRING, order_status STRING, order_total STRING, sales_channel STRING, attrs_json STRING, order_date STRING');

CREATE OR REPLACE TABLE trino_migration_demo_run4.trino_src.order_items_raw AS
SELECT * FROM read_files(
  '/Volumes/trino_migration_demo_run4/trino_src/landing/order_items.csv',
  format => 'csv', header => true, escape => '"',
  schema => 'order_item_id STRING, order_id STRING, sku STRING, quantity STRING, unit_price STRING, discount_pct STRING');

CREATE OR REPLACE TABLE trino_migration_demo_run4.trino_src.customers_raw AS
SELECT * FROM read_files(
  '/Volumes/trino_migration_demo_run4/trino_src/landing/customers.csv',
  format => 'csv', header => true, escape => '"',
  schema => 'customer_id STRING, customer_code STRING, full_name STRING, email STRING, region STRING, signup_date STRING, is_active STRING, created_at STRING');

CREATE OR REPLACE TABLE trino_migration_demo_run4.trino_src.customer_tags_raw AS
SELECT * FROM read_files(
  '/Volumes/trino_migration_demo_run4/trino_src/landing/customer_tags.csv',
  format => 'csv', header => true, escape => '"',
  schema => 'customer_id STRING, tag STRING');

CREATE OR REPLACE TABLE trino_migration_demo_run4.trino_src.daily_revenue_raw AS
SELECT * FROM read_files(
  '/Volumes/trino_migration_demo_run4/trino_src/landing/daily_revenue.csv',
  format => 'csv', header => true, escape => '"',
  schema => 'order_date STRING, region STRING, promo_group STRING, order_count STRING, gross_revenue STRING, avg_order_value STRING');

CREATE OR REPLACE TABLE trino_migration_demo_run4.trino_src.customer_ltv_raw AS
SELECT * FROM read_files(
  '/Volumes/trino_migration_demo_run4/trino_src/landing/customer_ltv.csv',
  format => 'csv', header => true, escape => '"',
  schema => 'customer_id STRING, customer_code STRING, region STRING, first_order_ts STRING, last_order_ts STRING, lifetime_orders STRING, lifetime_revenue STRING, avg_order_value STRING, active_days STRING, first_order_month STRING, tags_json STRING');
