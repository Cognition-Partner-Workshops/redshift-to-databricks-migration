-- Per-column aggregates for both marts. Every row must show delta = 0.
SELECT metric, trino_value, databricks_value, databricks_value - trino_value AS delta
FROM (
  SELECT 'daily_revenue.gross_revenue SUM' AS metric,
         (SELECT SUM(gross_revenue) FROM trino_migration_demo_run4.trino_src.daily_revenue) AS trino_value,
         (SELECT SUM(gross_revenue) FROM trino_migration_demo_run4.mart.daily_revenue)      AS databricks_value
  UNION ALL
  SELECT 'daily_revenue.order_count SUM',
         (SELECT SUM(order_count) FROM trino_migration_demo_run4.trino_src.daily_revenue),
         (SELECT SUM(order_count) FROM trino_migration_demo_run4.mart.daily_revenue)
  UNION ALL
  SELECT 'daily_revenue.avg_order_value SUM',
         (SELECT SUM(avg_order_value) FROM trino_migration_demo_run4.trino_src.daily_revenue),
         (SELECT SUM(avg_order_value) FROM trino_migration_demo_run4.mart.daily_revenue)
  UNION ALL
  SELECT 'daily_revenue.distinct order_date',
         (SELECT count(DISTINCT order_date) FROM trino_migration_demo_run4.trino_src.daily_revenue),
         (SELECT count(DISTINCT order_date) FROM trino_migration_demo_run4.mart.daily_revenue)
  UNION ALL
  SELECT 'daily_revenue.distinct region',
         (SELECT count(DISTINCT region) FROM trino_migration_demo_run4.trino_src.daily_revenue),
         (SELECT count(DISTINCT region) FROM trino_migration_demo_run4.mart.daily_revenue)
  UNION ALL
  SELECT 'daily_revenue.distinct promo_group',
         (SELECT count(DISTINCT promo_group) FROM trino_migration_demo_run4.trino_src.daily_revenue),
         (SELECT count(DISTINCT promo_group) FROM trino_migration_demo_run4.mart.daily_revenue)
  UNION ALL
  SELECT 'customer_ltv.lifetime_revenue SUM',
         (SELECT SUM(lifetime_revenue) FROM trino_migration_demo_run4.trino_src.customer_ltv),
         (SELECT SUM(lifetime_revenue) FROM trino_migration_demo_run4.mart.customer_ltv)
  UNION ALL
  SELECT 'customer_ltv.avg_order_value SUM',
         (SELECT SUM(avg_order_value) FROM trino_migration_demo_run4.trino_src.customer_ltv),
         (SELECT SUM(avg_order_value) FROM trino_migration_demo_run4.mart.customer_ltv)
  UNION ALL
  SELECT 'customer_ltv.lifetime_orders SUM',
         (SELECT SUM(lifetime_orders) FROM trino_migration_demo_run4.trino_src.customer_ltv),
         (SELECT SUM(lifetime_orders) FROM trino_migration_demo_run4.mart.customer_ltv)
  UNION ALL
  SELECT 'customer_ltv.active_days SUM',
         (SELECT SUM(active_days) FROM trino_migration_demo_run4.trino_src.customer_ltv),
         (SELECT SUM(active_days) FROM trino_migration_demo_run4.mart.customer_ltv)
  UNION ALL
  SELECT 'customer_ltv.tag count SUM',
         (SELECT SUM(size(tags)) FROM trino_migration_demo_run4.trino_src.customer_ltv),
         (SELECT SUM(size(tags)) FROM trino_migration_demo_run4.mart.customer_ltv)
  UNION ALL
  SELECT 'customer_ltv.distinct first_order_month',
         (SELECT count(DISTINCT first_order_month) FROM trino_migration_demo_run4.trino_src.customer_ltv),
         (SELECT count(DISTINCT first_order_month) FROM trino_migration_demo_run4.mart.customer_ltv)
  UNION ALL
  SELECT 'customer_ltv.max last_order_ts (epoch s)',
         (SELECT CAST(unix_timestamp(max(last_order_ts)) AS DECIMAL(38,6)) FROM trino_migration_demo_run4.trino_src.customer_ltv),
         (SELECT CAST(unix_timestamp(max(last_order_ts)) AS DECIMAL(38,6)) FROM trino_migration_demo_run4.mart.customer_ltv)
  UNION ALL
  SELECT 'customer_ltv.min first_order_ts (epoch s)',
         (SELECT CAST(unix_timestamp(min(first_order_ts)) AS DECIMAL(38,6)) FROM trino_migration_demo_run4.trino_src.customer_ltv),
         (SELECT CAST(unix_timestamp(min(first_order_ts)) AS DECIMAL(38,6)) FROM trino_migration_demo_run4.mart.customer_ltv)
)
ORDER BY metric
