-- Land the Trino CLI CSV exports (export.sh, --output-format CSV_HEADER; MAP/ARRAY columns exported as JSON text)
-- into the trino_src tables declared in ddl/05_trino_src_tables.sql. Reconciliation baseline; never rebuilt.
INSERT OVERWRITE trino_migration_demo.trino_src.core_orders
SELECT
    CAST(order_id AS BIGINT)                        AS order_id,
    CAST(customer_id AS INT)                        AS customer_id,
    CAST(order_ts AS TIMESTAMP)                     AS order_ts,
    order_status,
    CAST(order_total AS DECIMAL(12, 2))             AS order_total,
    sales_channel,
    from_json(attrs, 'MAP<STRING, STRING>')         AS attrs,
    CAST(order_date AS DATE)                        AS order_date
FROM read_files(
    '/Volumes/trino_migration_demo/trino_src/landing/csv/core_orders.csv',
    format => 'csv', header => true, escape => '"',
    schema => 'order_id STRING, customer_id STRING, order_ts STRING, order_status STRING, order_total STRING, sales_channel STRING, attrs STRING, order_date STRING'
);

INSERT OVERWRITE trino_migration_demo.trino_src.core_order_items
SELECT
    CAST(order_item_id AS BIGINT)        AS order_item_id,
    CAST(order_id AS BIGINT)             AS order_id,
    sku,
    CAST(quantity AS SMALLINT)           AS quantity,
    CAST(unit_price AS DECIMAL(10, 2))   AS unit_price,
    CAST(discount_pct AS DECIMAL(5, 4))  AS discount_pct
FROM read_files(
    '/Volumes/trino_migration_demo/trino_src/landing/csv/core_order_items.csv',
    format => 'csv', header => true, escape => '"',
    schema => 'order_item_id STRING, order_id STRING, sku STRING, quantity STRING, unit_price STRING, discount_pct STRING'
);

INSERT OVERWRITE trino_migration_demo.trino_src.ops_customers
SELECT
    CAST(customer_id AS INT)            AS customer_id,
    CAST(customer_code AS CHAR(12))     AS customer_code,
    CAST(full_name AS VARCHAR(120))     AS full_name,
    CAST(email AS VARCHAR(160))         AS email,
    CAST(region AS CHAR(4))             AS region,
    CAST(signup_date AS DATE)           AS signup_date,
    CAST(is_active AS BOOLEAN)          AS is_active,
    CAST(created_at AS TIMESTAMP)       AS created_at
FROM read_files(
    '/Volumes/trino_migration_demo/trino_src/landing/csv/ops_customers.csv',
    format => 'csv', header => true, escape => '"',
    schema => 'customer_id STRING, customer_code STRING, full_name STRING, email STRING, region STRING, signup_date STRING, is_active STRING, created_at STRING'
);

INSERT OVERWRITE trino_migration_demo.trino_src.ops_customer_tags
SELECT CAST(customer_id AS INT) AS customer_id, tag
FROM read_files(
    '/Volumes/trino_migration_demo/trino_src/landing/csv/ops_customer_tags.csv',
    format => 'csv', header => true, escape => '"',
    schema => 'customer_id STRING, tag STRING'
);

INSERT OVERWRITE trino_migration_demo.trino_src.mart_daily_revenue
SELECT
    CAST(order_date AS TIMESTAMP)               AS order_date,
    CAST(region AS CHAR(4))                     AS region,
    CAST(promo_group AS VARCHAR(11))            AS promo_group,
    CAST(order_count AS BIGINT)                 AS order_count,
    CAST(gross_revenue AS DECIMAL(38, 2))       AS gross_revenue,
    CAST(avg_order_value AS DECIMAL(38, 6))     AS avg_order_value
FROM read_files(
    '/Volumes/trino_migration_demo/trino_src/landing/csv/mart_daily_revenue.csv',
    format => 'csv', header => true, escape => '"',
    schema => 'order_date STRING, region STRING, promo_group STRING, order_count STRING, gross_revenue STRING, avg_order_value STRING'
);

INSERT OVERWRITE trino_migration_demo.trino_src.mart_customer_ltv
SELECT
    CAST(customer_id AS INT)                    AS customer_id,
    CAST(customer_code AS CHAR(12))             AS customer_code,
    CAST(region AS CHAR(4))                     AS region,
    CAST(first_order_ts AS TIMESTAMP)           AS first_order_ts,
    CAST(last_order_ts AS TIMESTAMP)            AS last_order_ts,
    CAST(lifetime_orders AS BIGINT)             AS lifetime_orders,
    CAST(lifetime_revenue AS DECIMAL(38, 2))    AS lifetime_revenue,
    CAST(avg_order_value AS DECIMAL(12, 2))     AS avg_order_value,
    CAST(active_days AS BIGINT)                 AS active_days,
    first_order_month,
    from_json(tags, 'ARRAY<STRING>')            AS tags
FROM read_files(
    '/Volumes/trino_migration_demo/trino_src/landing/csv/mart_customer_ltv.csv',
    format => 'csv', header => true, escape => '"',
    schema => 'customer_id STRING, customer_code STRING, region STRING, first_order_ts STRING, last_order_ts STRING, lifetime_orders STRING, lifetime_revenue STRING, avg_order_value STRING, active_days STRING, first_order_month STRING, tags STRING'
);
