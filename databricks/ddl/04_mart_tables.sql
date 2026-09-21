-- lake.mart.* were Parquet folders under file:///data/warehouse/mart that the ETL dropped and re-created with CTAS.
-- Databricks CTAS relaxes CHAR/VARCHAR to STRING, so the marts are declared here with the Trino column types and
-- the ETL uses INSERT OVERWRITE (atomic, versioned) instead of DROP + CTAS.
CREATE TABLE IF NOT EXISTS trino_migration_demo.mart.daily_revenue (
    order_date      TIMESTAMP,
    region          CHAR(4),
    promo_group     VARCHAR(11),
    order_count     BIGINT,
    gross_revenue   DECIMAL(38, 2),
    avg_order_value DECIMAL(38, 6)
);

CREATE TABLE IF NOT EXISTS trino_migration_demo.mart.customer_ltv (
    customer_id       INT,
    customer_code     CHAR(12),
    region            CHAR(4),
    first_order_ts    TIMESTAMP,
    last_order_ts     TIMESTAMP,
    lifetime_orders   BIGINT,
    lifetime_revenue  DECIMAL(38, 2),
    avg_order_value   DECIMAL(12, 2),
    active_days       BIGINT,
    first_order_month STRING,
    tags              ARRAY<STRING>
);
