-- Raw Trino snapshot. CSVs exported by recon/trino/export_snapshot.sql and uploaded to
-- /Volumes/trino_migration_demo/trino_src/landing/. Types mirror the Trino result types.
CREATE OR REPLACE TABLE trino_migration_demo.trino_src.core_orders
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS
SELECT
    CAST(order_id AS BIGINT)                          AS order_id,
    CAST(customer_id AS INT)                          AS customer_id,
    CAST(order_ts AS TIMESTAMP_NTZ)                   AS order_ts,
    order_status,
    CAST(order_total AS DECIMAL(12, 2))               AS order_total,
    sales_channel,
    from_json(attrs, 'MAP<STRING, STRING>')           AS attrs,
    CAST(order_date AS DATE)                          AS order_date
FROM read_files('/Volumes/trino_migration_demo/trino_src/landing/core_orders.csv',
                format => 'csv', header => true, inferSchema => false, escape => '"');

CREATE OR REPLACE TABLE trino_migration_demo.trino_src.core_order_items
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS
SELECT
    CAST(order_item_id AS BIGINT)        AS order_item_id,
    CAST(order_id AS BIGINT)             AS order_id,
    sku,
    CAST(quantity AS SMALLINT)           AS quantity,
    CAST(unit_price AS DECIMAL(10, 2))   AS unit_price,
    CAST(discount_pct AS DECIMAL(5, 4))  AS discount_pct
FROM read_files('/Volumes/trino_migration_demo/trino_src/landing/core_order_items.csv',
                format => 'csv', header => true, inferSchema => false, escape => '"');

CREATE OR REPLACE TABLE trino_migration_demo.trino_src.ops_customers
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS
SELECT
    CAST(customer_id AS INT)             AS customer_id,
    CAST(customer_code AS CHAR(12))      AS customer_code,
    full_name,
    email,
    CAST(region AS CHAR(4))              AS region,
    CAST(signup_date AS DATE)            AS signup_date,
    CAST(is_active AS BOOLEAN)           AS is_active,
    CAST(created_at AS TIMESTAMP_NTZ)    AS created_at
FROM read_files('/Volumes/trino_migration_demo/trino_src/landing/ops_customers.csv',
                format => 'csv', header => true, inferSchema => false, escape => '"',
                ignoreLeadingWhiteSpace => false, ignoreTrailingWhiteSpace => false);

CREATE OR REPLACE TABLE trino_migration_demo.trino_src.ops_customer_tags
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS
SELECT
    CAST(customer_id AS INT) AS customer_id,
    tag
FROM read_files('/Volumes/trino_migration_demo/trino_src/landing/ops_customer_tags.csv',
                format => 'csv', header => true, inferSchema => false, escape => '"');

CREATE OR REPLACE TABLE trino_migration_demo.trino_src.mart_daily_revenue
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS
SELECT
    CAST(order_date AS TIMESTAMP_NTZ)          AS order_date,
    CAST(region AS CHAR(4))                    AS region,
    promo_group,
    CAST(order_count AS BIGINT)                AS order_count,
    CAST(gross_revenue AS DECIMAL(38, 2))      AS gross_revenue,
    CAST(avg_order_value AS DECIMAL(38, 6))    AS avg_order_value
FROM read_files('/Volumes/trino_migration_demo/trino_src/landing/mart_daily_revenue.csv',
                format => 'csv', header => true, inferSchema => false, escape => '"',
                ignoreLeadingWhiteSpace => false, ignoreTrailingWhiteSpace => false);

CREATE OR REPLACE TABLE trino_migration_demo.trino_src.mart_customer_ltv
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS
SELECT
    CAST(customer_id AS INT)                   AS customer_id,
    CAST(customer_code AS CHAR(12))            AS customer_code,
    CAST(region AS CHAR(4))                    AS region,
    CAST(first_order_ts AS TIMESTAMP_NTZ)      AS first_order_ts,
    CAST(last_order_ts AS TIMESTAMP_NTZ)       AS last_order_ts,
    CAST(lifetime_orders AS BIGINT)            AS lifetime_orders,
    CAST(lifetime_revenue AS DECIMAL(38, 2))   AS lifetime_revenue,
    CAST(avg_order_value AS DECIMAL(12, 2))    AS avg_order_value,
    CAST(active_days AS BIGINT)                AS active_days,
    first_order_month,
    from_json(tags, 'ARRAY<STRING>')           AS tags
FROM read_files('/Volumes/trino_migration_demo/trino_src/landing/mart_customer_ltv.csv',
                format => 'csv', header => true, inferSchema => false, escape => '"',
                ignoreLeadingWhiteSpace => false, ignoreTrailingWhiteSpace => false);
