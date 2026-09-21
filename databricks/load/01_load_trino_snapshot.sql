CREATE SCHEMA IF NOT EXISTS trino_migration_demo.trino_src;

CREATE OR REPLACE TABLE trino_migration_demo.trino_src.core_orders AS
SELECT
    CAST(order_id AS BIGINT) AS order_id,
    CAST(customer_id AS INT) AS customer_id,
    TO_TIMESTAMP(order_ts) AS order_ts,
    CAST(order_status AS STRING) AS order_status,
    CAST(order_total AS DECIMAL(12, 2)) AS order_total,
    CAST(sales_channel AS STRING) AS sales_channel,
    FROM_JSON(attrs, 'MAP<STRING,STRING>') AS attrs,
    TO_DATE(order_date) AS order_date
FROM READ_FILES(
    '/Volumes/trino_migration_demo/landing/files/core_orders.csv',
    FORMAT => 'csv',
    HEADER => true,
    inferColumnTypes => false,
    ESCAPE => '"'
);

CREATE OR REPLACE TABLE trino_migration_demo.trino_src.core_order_items AS
SELECT
    CAST(order_item_id AS BIGINT) AS order_item_id,
    CAST(order_id AS BIGINT) AS order_id,
    CAST(sku AS STRING) AS sku,
    CAST(quantity AS SMALLINT) AS quantity,
    CAST(unit_price AS DECIMAL(10, 2)) AS unit_price,
    CAST(discount_pct AS DECIMAL(5, 4)) AS discount_pct
FROM READ_FILES(
    '/Volumes/trino_migration_demo/landing/files/core_order_items.csv',
    FORMAT => 'csv',
    HEADER => true,
    inferColumnTypes => false,
    ESCAPE => '"'
);

CREATE OR REPLACE TABLE trino_migration_demo.trino_src.ops_customers AS
SELECT
    CAST(customer_id AS INT) AS customer_id,
    CAST(customer_code AS STRING) AS customer_code,
    CAST(full_name AS STRING) AS full_name,
    CAST(email AS STRING) AS email,
    CAST(region AS STRING) AS region,
    TO_DATE(signup_date) AS signup_date,
    CAST(is_active AS BOOLEAN) AS is_active,
    TO_TIMESTAMP(created_at) AS created_at
FROM READ_FILES(
    '/Volumes/trino_migration_demo/landing/files/ops_customers.csv',
    FORMAT => 'csv',
    HEADER => true,
    inferColumnTypes => false,
    ESCAPE => '"'
);

CREATE OR REPLACE TABLE trino_migration_demo.trino_src.ops_customer_tags AS
SELECT
    CAST(customer_id AS INT) AS customer_id,
    CAST(tag AS STRING) AS tag
FROM READ_FILES(
    '/Volumes/trino_migration_demo/landing/files/ops_customer_tags.csv',
    FORMAT => 'csv',
    HEADER => true,
    inferColumnTypes => false,
    ESCAPE => '"'
);

CREATE OR REPLACE TABLE trino_migration_demo.trino_src.mart_daily_revenue AS
SELECT
    TO_TIMESTAMP(order_date) AS order_date,
    CAST(region AS STRING) AS region,
    CAST(promo_group AS STRING) AS promo_group,
    CAST(order_count AS BIGINT) AS order_count,
    CAST(gross_revenue AS DECIMAL(18, 2)) AS gross_revenue,
    CAST(avg_order_value AS DECIMAL(18, 2)) AS avg_order_value
FROM READ_FILES(
    '/Volumes/trino_migration_demo/landing/files/mart_daily_revenue.csv',
    FORMAT => 'csv',
    HEADER => true,
    inferColumnTypes => false,
    ESCAPE => '"'
);

CREATE OR REPLACE TABLE trino_migration_demo.trino_src.mart_customer_ltv AS
SELECT
    CAST(customer_id AS INT) AS customer_id,
    CAST(customer_code AS STRING) AS customer_code,
    CAST(region AS STRING) AS region,
    TO_TIMESTAMP(first_order_ts) AS first_order_ts,
    TO_TIMESTAMP(last_order_ts) AS last_order_ts,
    CAST(lifetime_orders AS BIGINT) AS lifetime_orders,
    CAST(lifetime_revenue AS DECIMAL(18, 2)) AS lifetime_revenue,
    CAST(avg_order_value AS DECIMAL(18, 2)) AS avg_order_value,
    CAST(active_days AS BIGINT) AS active_days,
    CAST(first_order_month AS STRING) AS first_order_month,
    FROM_JSON(tags, 'ARRAY<STRING>') AS tags
FROM READ_FILES(
    '/Volumes/trino_migration_demo/landing/files/mart_customer_ltv.csv',
    FORMAT => 'csv',
    HEADER => true,
    inferColumnTypes => false,
    ESCAPE => '"'
);

CREATE OR REPLACE TABLE trino_migration_demo.trino_src.report_20 AS
SELECT
    CAST(region AS STRING) AS region,
    CAST(customers AS BIGINT) AS customers,
    CAST(revenue AS DECIMAL(18, 2)) AS revenue,
    CAST(aov AS DECIMAL(18, 2)) AS aov,
    CAST(tag_count AS BIGINT) AS tag_count
FROM READ_FILES(
    '/Volumes/trino_migration_demo/landing/files/report_20.csv',
    FORMAT => 'csv',
    HEADER => true,
    inferColumnTypes => false,
    ESCAPE => '"'
);

CREATE OR REPLACE TABLE trino_migration_demo.trino_src.report_21 AS
SELECT
    TO_TIMESTAMP(order_date) AS order_date,
    CAST(promo_group AS STRING) AS promo_group,
    CAST(revenue AS DECIMAL(18, 2)) AS revenue,
    CAST(orders AS BIGINT) AS orders
FROM READ_FILES(
    '/Volumes/trino_migration_demo/landing/files/report_21.csv',
    FORMAT => 'csv',
    HEADER => true,
    inferColumnTypes => false,
    ESCAPE => '"'
);

CREATE OR REPLACE TABLE trino_migration_demo.trino_src.report_22 AS
SELECT
    CAST(promo AS STRING) AS promo,
    CAST(orders AS BIGINT) AS orders,
    CAST(median_order_total AS DECIMAL(18, 5)) AS median_order_total,
    CAST(average_order_total AS DECIMAL(18, 2)) AS average_order_total
FROM READ_FILES(
    '/Volumes/trino_migration_demo/landing/files/report_22.csv',
    FORMAT => 'csv',
    HEADER => true,
    inferColumnTypes => false,
    ESCAPE => '"'
);
