-- Report parity. Reports 20 and 21 are run twice on Databricks: once over the rebuilt marts (converted SQL)
-- and once over the Trino snapshot marts (what the Trino report returned), then diffed both ways. Must be 0.
-- Report 22 reads core.orders directly; its Trino output is non-deterministic (approx_percentile), so the
-- converted report is checked against the exact median (percentile) instead. See docs/evidence for the Trino runs.
WITH r20_db AS (
    SELECT CAST(region AS STRING) region, COUNT(*) AS customers, SUM(lifetime_revenue) AS revenue, AVG(avg_order_value) AS aov, SUM(cardinality(tags)) AS tag_count
    FROM trino_migration_demo.mart.customer_ltv GROUP BY region),
r20_tr AS (
    SELECT CAST(region AS STRING) region, COUNT(*) AS customers, SUM(lifetime_revenue) AS revenue, AVG(avg_order_value) AS aov, SUM(cardinality(tags)) AS tag_count
    FROM trino_migration_demo.trino_src.mart_customer_ltv GROUP BY region),
r21_db AS (
    SELECT order_date, CAST(promo_group AS STRING) promo_group, SUM(gross_revenue) AS revenue, SUM(order_count) AS orders
    FROM trino_migration_demo.mart.daily_revenue WHERE order_date >= date_add(current_date(), -30) GROUP BY order_date, promo_group),
r21_tr AS (
    SELECT order_date, CAST(promo_group AS STRING) promo_group, SUM(gross_revenue) AS revenue, SUM(order_count) AS orders
    FROM trino_migration_demo.trino_src.mart_daily_revenue WHERE order_date >= date_add(current_date(), -30) GROUP BY order_date, promo_group)
SELECT '20_region_topline' AS report, 'rows' AS check, (SELECT count(*) FROM r20_db) AS databricks, (SELECT count(*) FROM r20_tr) AS trino
UNION ALL SELECT '20_region_topline', 'databricks EXCEPT trino', (SELECT count(*) FROM (SELECT * FROM r20_db EXCEPT ALL SELECT * FROM r20_tr)), 0
UNION ALL SELECT '20_region_topline', 'trino EXCEPT databricks', (SELECT count(*) FROM (SELECT * FROM r20_tr EXCEPT ALL SELECT * FROM r20_db)), 0
UNION ALL SELECT '21_channel_trend', 'rows', (SELECT count(*) FROM r21_db), (SELECT count(*) FROM r21_tr)
UNION ALL SELECT '21_channel_trend', 'databricks EXCEPT trino', (SELECT count(*) FROM (SELECT * FROM r21_db EXCEPT ALL SELECT * FROM r21_tr)), 0
UNION ALL SELECT '21_channel_trend', 'trino EXCEPT databricks', (SELECT count(*) FROM (SELECT * FROM r21_tr EXCEPT ALL SELECT * FROM r21_db)), 0
ORDER BY report, check;

-- 22_promo_lift: converted report (percentile_approx, accuracy 10000) vs the exact order statistics of the same
-- data. With 1,250 orders per promo the median sits between the 625th and 626th values; percentile_approx returns
-- one of them, so the check is lower_middle <= median_order_total <= upper_middle. AVG must match exactly.
-- Trino's approx_percentile is randomized (see docs/evidence/before/report_22_promo_lift_run*.tsv) and cannot be
-- reproduced value-for-value; the Trino runs are recorded as evidence, not used as a target.
WITH conv AS (
    SELECT attr_value AS promo, COUNT(*) AS orders, percentile_approx(order_total, 0.5, 10000) AS median_order_total, AVG(order_total) AS average_order_total
    FROM trino_migration_demo.core.orders o LATERAL VIEW explode(o.attrs) u AS attr_key, attr_value
    WHERE attr_key = 'promo' GROUP BY attr_value),
ranked AS (
    SELECT attrs['promo'] AS promo, order_total, row_number() OVER (PARTITION BY attrs['promo'] ORDER BY order_total) AS rn, count(*) OVER (PARTITION BY attrs['promo']) AS n
    FROM trino_migration_demo.core.orders),
exact AS (
    SELECT promo, max(n) AS orders,
           min(if(rn = (n + 1) DIV 2, order_total, NULL)) AS lower_middle,
           min(if(rn = n DIV 2 + 1, order_total, NULL)) AS upper_middle,
           AVG(order_total) AS average_order_total
    FROM ranked GROUP BY promo)
SELECT c.promo, c.orders, e.orders AS exact_orders, c.median_order_total, e.lower_middle, e.upper_middle,
       c.median_order_total BETWEEN e.lower_middle AND e.upper_middle AS median_is_a_true_middle_value,
       c.average_order_total - e.average_order_total AS avg_diff
FROM conv c JOIN exact e ON e.promo = c.promo
ORDER BY c.median_order_total DESC;
