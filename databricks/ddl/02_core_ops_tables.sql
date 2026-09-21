-- Typed landing of the four Trino source tables that the ETL reads.
-- Type choices that matter:
--   TIMESTAMP_NTZ  - Trino timestamp(3) is wall-clock, Databricks TIMESTAMP is zoned
--   MAP<STRING,STRING> for orders.attrs, rebuilt from the exported JSON
--   CHAR(12)/CHAR(4) kept as CHAR so the Postgres blank padding survives the move
CREATE OR REPLACE TABLE trino_migration_demo_run4.core.orders (
  order_id      BIGINT,
  customer_id   INT,
  order_ts      TIMESTAMP_NTZ,
  order_status  STRING,
  order_total   DECIMAL(12, 2),
  sales_channel STRING,
  attrs         MAP<STRING, STRING>,
  order_date    DATE
);

INSERT INTO trino_migration_demo_run4.core.orders
SELECT
  CAST(order_id AS BIGINT),
  CAST(customer_id AS INT),
  CAST(order_ts AS TIMESTAMP_NTZ),
  order_status,
  CAST(order_total AS DECIMAL(12, 2)),
  sales_channel,
  from_json(attrs_json, 'MAP<STRING, STRING>'),
  CAST(order_date AS DATE)
FROM trino_migration_demo_run4.trino_src.orders_raw;

CREATE OR REPLACE TABLE trino_migration_demo_run4.core.order_items (
  order_item_id BIGINT,
  order_id      BIGINT,
  sku           STRING,
  quantity      SMALLINT,
  unit_price    DECIMAL(10, 2),
  discount_pct  DECIMAL(5, 4)
);

INSERT INTO trino_migration_demo_run4.core.order_items
SELECT
  CAST(order_item_id AS BIGINT),
  CAST(order_id AS BIGINT),
  sku,
  CAST(quantity AS SMALLINT),
  CAST(unit_price AS DECIMAL(10, 2)),
  CAST(discount_pct AS DECIMAL(5, 4))
FROM trino_migration_demo_run4.trino_src.order_items_raw;

CREATE OR REPLACE TABLE trino_migration_demo_run4.ops.customers (
  customer_id   INT,
  customer_code CHAR(12),
  full_name     STRING,
  email         STRING,
  region        CHAR(4),
  signup_date   DATE,
  is_active     BOOLEAN,
  created_at    TIMESTAMP_NTZ
);

INSERT INTO trino_migration_demo_run4.ops.customers
SELECT
  CAST(customer_id AS INT),
  CAST(customer_code AS CHAR(12)),
  full_name,
  email,
  CAST(region AS CHAR(4)),
  CAST(signup_date AS DATE),
  CAST(is_active AS BOOLEAN),
  CAST(created_at AS TIMESTAMP_NTZ)
FROM trino_migration_demo_run4.trino_src.customers_raw;

CREATE OR REPLACE TABLE trino_migration_demo_run4.ops.customer_tags (
  customer_id INT,
  tag         STRING
);

INSERT INTO trino_migration_demo_run4.ops.customer_tags
SELECT CAST(customer_id AS INT), tag
FROM trino_migration_demo_run4.trino_src.customer_tags_raw;
