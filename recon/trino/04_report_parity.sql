-- Report parity: each converted report run against the rebuilt Databricks mart,
-- compared to the same report run against the Trino snapshot.

-- Report 20 - region topline. Every delta column must be 0.
WITH trino_20 AS (
  SELECT region, COUNT(*) AS customers,
         CAST(SUM(lifetime_revenue) AS DECIMAL(38,2)) AS revenue,
         CAST(AVG(avg_order_value) AS DECIMAL(12,2))  AS aov,
         SUM(size(tags)) AS tag_count
  FROM trino_migration_demo_run4.trino_src.customer_ltv GROUP BY region
),
dbx_20 AS (
  SELECT region, COUNT(*) AS customers,
         CAST(SUM(lifetime_revenue) AS DECIMAL(38,2)) AS revenue,
         CAST(AVG(avg_order_value) AS DECIMAL(12,2))  AS aov,
         SUM(size(tags)) AS tag_count
  FROM trino_migration_demo_run4.mart.customer_ltv GROUP BY region
)
SELECT 'report_20_region_topline' AS report, t.region AS grain,
       d.customers - t.customers AS d_customers,
       d.revenue   - t.revenue   AS d_revenue,
       d.aov       - t.aov       AS d_aov,
       d.tag_count - t.tag_count AS d_tag_count
FROM trino_20 t FULL OUTER JOIN dbx_20 d USING (region)
ORDER BY grain;

-- Report 21 - channel trend. Every delta column must be 0 and the row counts equal.
WITH trino_21 AS (
  SELECT order_date, promo_group,
         CAST(SUM(gross_revenue) AS DECIMAL(38,2)) AS revenue, SUM(order_count) AS orders
  FROM trino_migration_demo_run4.trino_src.daily_revenue
  WHERE order_date >= date_sub(current_date(), 30)
  GROUP BY order_date, promo_group
),
dbx_21 AS (
  SELECT order_date, promo_group,
         CAST(SUM(gross_revenue) AS DECIMAL(38,2)) AS revenue, SUM(order_count) AS orders
  FROM trino_migration_demo_run4.mart.daily_revenue
  WHERE order_date >= date_sub(current_date(), 30)
  GROUP BY order_date, promo_group
)
-- Per-grain mismatch counts and max absolute deltas, not signed totals: a grain that is
-- too high and one that is too low would cancel each other out in a SUM.
SELECT 'report_21_channel_trend' AS report,
       count(*)                                                   AS rows_compared,
       sum(CASE WHEN t.order_date IS NULL OR d.order_date IS NULL THEN 1 ELSE 0 END) AS unmatched_rows,
       sum(CASE WHEN NOT (d.revenue <=> t.revenue) THEN 1 ELSE 0 END) AS revenue_mismatched_rows,
       sum(CASE WHEN NOT (d.orders  <=> t.orders)  THEN 1 ELSE 0 END) AS orders_mismatched_rows,
       max(abs(coalesce(d.revenue, 0) - coalesce(t.revenue, 0)))  AS max_abs_revenue_delta,
       max(abs(coalesce(d.orders, 0)  - coalesce(t.orders, 0)))   AS max_abs_orders_delta
FROM trino_21 t FULL OUTER JOIN dbx_21 d USING (order_date, promo_group);

-- Report 22 - promo lift. Source table is shared, so orders / average_order_total must
-- match exactly. median_order_total is compared as Trino's approx_percentile against
-- both the Databricks approximate and exact medians.
WITH trino_22 AS (
  SELECT attr_value AS promo, COUNT(*) AS orders,
         CAST(AVG(order_total) AS DECIMAL(12,2)) AS average_order_total
  FROM trino_migration_demo_run4.core.orders o
  LATERAL VIEW explode(o.attrs) u AS attr_key, attr_value
  WHERE attr_key = 'promo' GROUP BY attr_value
),
dbx_22 AS (
  SELECT attr_value AS promo, COUNT(*) AS orders,
         percentile_approx(order_total, 0.5) AS median_order_total,
         CAST(percentile(order_total, 0.5) AS DECIMAL(12,2)) AS exact_median,
         CAST(AVG(order_total) AS DECIMAL(12,2)) AS average_order_total
  FROM trino_migration_demo_run4.core.orders o
  LATERAL VIEW explode(o.attrs) u AS attr_key, attr_value
  WHERE attr_key = 'promo' GROUP BY attr_value
)
SELECT 'report_22_promo_lift' AS report, t.promo AS grain,
       d.orders - t.orders                           AS d_orders,
       d.average_order_total - t.average_order_total AS d_average_order_total,
       d.median_order_total                          AS dbx_approx_median,
       d.exact_median                                AS dbx_exact_median
FROM trino_22 t JOIN dbx_22 d USING (promo)
ORDER BY grain
