-- Row-level symmetric diffs. Every count must be 0.
-- daily_revenue key: (order_date, region, promo_group)
WITH t AS (
  SELECT CAST(order_date AS DATE) order_date, region, promo_group, order_count,
         CAST(gross_revenue AS DECIMAL(18,2)) gross_revenue,
         CAST(avg_order_value AS DECIMAL(18,2)) avg_order_value
  FROM trino_migration_demo.trino_src.mart_daily_revenue
), d AS (
  SELECT CAST(order_date AS DATE) order_date, region, promo_group, order_count,
         CAST(gross_revenue AS DECIMAL(18,2)) gross_revenue,
         CAST(avg_order_value AS DECIMAL(18,2)) avg_order_value
  FROM trino_migration_demo.mart.daily_revenue
)
SELECT 'daily_revenue trino-minus-dbx' AS diff, COUNT(*) AS rows_ FROM (SELECT * FROM t EXCEPT SELECT * FROM d)
UNION ALL
SELECT 'daily_revenue dbx-minus-trino', COUNT(*) FROM (SELECT * FROM d EXCEPT SELECT * FROM t)
UNION ALL
SELECT 'daily_revenue aov mismatch (raw, unrounded)', COUNT(*)
FROM trino_migration_demo.trino_src.mart_daily_revenue a
JOIN trino_migration_demo.mart.daily_revenue b
  ON CAST(a.order_date AS DATE) = CAST(b.order_date AS DATE) AND a.region = b.region AND a.promo_group = b.promo_group
WHERE a.avg_order_value <> b.avg_order_value
UNION ALL
SELECT 'customer_ltv trino-minus-dbx', COUNT(*) FROM (
  SELECT customer_id, customer_code, region, first_order_ts, last_order_ts, lifetime_orders,
         CAST(lifetime_revenue AS DECIMAL(18,2)), CAST(avg_order_value AS DECIMAL(18,2)),
         active_days, first_order_month, tags
  FROM trino_migration_demo.trino_src.mart_customer_ltv
  EXCEPT
  SELECT customer_id, customer_code, region, first_order_ts, last_order_ts, lifetime_orders,
         CAST(lifetime_revenue AS DECIMAL(18,2)), CAST(avg_order_value AS DECIMAL(18,2)),
         active_days, first_order_month, tags
  FROM trino_migration_demo.mart.customer_ltv)
UNION ALL
SELECT 'customer_ltv dbx-minus-trino', COUNT(*) FROM (
  SELECT customer_id, customer_code, region, first_order_ts, last_order_ts, lifetime_orders,
         CAST(lifetime_revenue AS DECIMAL(18,2)), CAST(avg_order_value AS DECIMAL(18,2)),
         active_days, first_order_month, tags
  FROM trino_migration_demo.mart.customer_ltv
  EXCEPT
  SELECT customer_id, customer_code, region, first_order_ts, last_order_ts, lifetime_orders,
         CAST(lifetime_revenue AS DECIMAL(18,2)), CAST(avg_order_value AS DECIMAL(18,2)),
         active_days, first_order_month, tags
  FROM trino_migration_demo.trino_src.mart_customer_ltv)
UNION ALL
SELECT 'customer_ltv aov mismatch (raw, unrounded)', COUNT(*)
FROM trino_migration_demo.trino_src.mart_customer_ltv a
JOIN trino_migration_demo.mart.customer_ltv b ON a.customer_id = b.customer_id
WHERE a.avg_order_value <> b.avg_order_value
