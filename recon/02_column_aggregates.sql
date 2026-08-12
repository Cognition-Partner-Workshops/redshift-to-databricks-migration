-- Reconciliation: per-column aggregates to the cent, Databricks marts vs
-- live Redshift marts via federation. Every numeric column is SUMmed at its
-- native scale (cents preserved); dates/timestamps compared via MIN/MAX;
-- text via COUNT(DISTINCT). Run on the Databricks SQL warehouse.

SELECT side, order_dates, min_order_date, max_order_date, regions, channel_groups,
       total_orders, gross_revenue_sum, avg_order_value_sum
FROM (
  SELECT 'redshift' AS side,
         COUNT(DISTINCT order_date)                     AS order_dates,
         MIN(order_date)                                AS min_order_date,
         MAX(order_date)                                AS max_order_date,
         COUNT(DISTINCT region)                         AS regions,
         COUNT(DISTINCT channel_group)                  AS channel_groups,
         SUM(order_count)                               AS total_orders,
         CAST(SUM(gross_revenue)   AS DECIMAL(38,2))    AS gross_revenue_sum,
         CAST(SUM(avg_order_value) AS DECIMAL(38,4))    AS avg_order_value_sum
  FROM redshift_src.mart.daily_revenue
  UNION ALL
  SELECT 'databricks',
         COUNT(DISTINCT order_date), MIN(order_date), MAX(order_date),
         COUNT(DISTINCT region), COUNT(DISTINCT channel_group),
         SUM(order_count),
         CAST(SUM(gross_revenue)   AS DECIMAL(38,2)),
         CAST(SUM(avg_order_value) AS DECIMAL(38,4))
  FROM migration_demo.mart.daily_revenue
) ORDER BY side;

SELECT side, customers, min_first_order_ts, max_last_order_ts, lifetime_orders_sum,
       lifetime_revenue_sum, avg_order_value_sum, active_days_sum
FROM (
  SELECT 'redshift' AS side,
         COUNT(DISTINCT customer_id)                    AS customers,
         MIN(first_order_ts)                            AS min_first_order_ts,
         MAX(last_order_ts)                             AS max_last_order_ts,
         SUM(lifetime_orders)                           AS lifetime_orders_sum,
         CAST(SUM(lifetime_revenue) AS DECIMAL(38,2))   AS lifetime_revenue_sum,
         CAST(SUM(avg_order_value)  AS DECIMAL(38,2))   AS avg_order_value_sum,
         SUM(active_days)                               AS active_days_sum
  FROM redshift_src.mart.customer_ltv
  UNION ALL
  SELECT 'databricks',
         COUNT(DISTINCT customer_id), MIN(first_order_ts), MAX(last_order_ts),
         SUM(lifetime_orders),
         CAST(SUM(lifetime_revenue) AS DECIMAL(38,2)),
         CAST(SUM(avg_order_value)  AS DECIMAL(38,2)),
         SUM(active_days)
  FROM migration_demo.mart.customer_ltv
) ORDER BY side;
