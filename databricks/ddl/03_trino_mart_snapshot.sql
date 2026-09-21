-- Typed snapshots of the two Trino marts. These are the reconciliation baseline:
-- the converted ETL writes trino_migration_demo_run4.mart.*, and recon compares it
-- against these tables. Types mirror the Trino DESCRIBE output exactly, including
-- decimal(38,2) / decimal(38,6) widths and the avg_order_value decimal(12,2) that
-- Trino's avg() keeps at the input scale.
CREATE OR REPLACE TABLE trino_migration_demo_run4.trino_src.daily_revenue (
  order_date      TIMESTAMP_NTZ,
  region          CHAR(4),
  promo_group     STRING,
  order_count     BIGINT,
  gross_revenue   DECIMAL(38, 2),
  avg_order_value DECIMAL(38, 6)
);

INSERT INTO trino_migration_demo_run4.trino_src.daily_revenue
SELECT
  CAST(order_date AS TIMESTAMP_NTZ),
  CAST(region AS CHAR(4)),
  promo_group,
  CAST(order_count AS BIGINT),
  CAST(gross_revenue AS DECIMAL(38, 2)),
  CAST(avg_order_value AS DECIMAL(38, 6))
FROM trino_migration_demo_run4.trino_src.daily_revenue_raw;

CREATE OR REPLACE TABLE trino_migration_demo_run4.trino_src.customer_ltv (
  customer_id       INT,
  customer_code     CHAR(12),
  region            CHAR(4),
  first_order_ts    TIMESTAMP_NTZ,
  last_order_ts     TIMESTAMP_NTZ,
  lifetime_orders   BIGINT,
  lifetime_revenue  DECIMAL(38, 2),
  avg_order_value   DECIMAL(12, 2),
  active_days       BIGINT,
  first_order_month STRING,
  tags              ARRAY<STRING>
);

INSERT INTO trino_migration_demo_run4.trino_src.customer_ltv
SELECT
  CAST(customer_id AS INT),
  CAST(customer_code AS CHAR(12)),
  CAST(region AS CHAR(4)),
  CAST(first_order_ts AS TIMESTAMP_NTZ),
  CAST(last_order_ts AS TIMESTAMP_NTZ),
  CAST(lifetime_orders AS BIGINT),
  CAST(lifetime_revenue AS DECIMAL(38, 2)),
  CAST(avg_order_value AS DECIMAL(12, 2)),
  CAST(active_days AS BIGINT),
  first_order_month,
  from_json(tags_json, 'ARRAY<STRING>')
FROM trino_migration_demo_run4.trino_src.customer_ltv_raw;
