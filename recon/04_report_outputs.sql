-- Reconciliation: report output comparison.
--
-- The legacy report SQL (sql/reports/) executes on Redshift via the Data API
-- and the converted SQL (databricks/reports/) executes on the Databricks
-- warehouse; recon/run_recon.py diffs the two result sets row by row.
-- The queries below are the federation-side equivalents used to spot-check
-- the same comparison entirely from Databricks: EXCEPT runs in both
-- directions (as in 03_row_level_except.sql) and every query must return
-- 0 rows for the pair to be identical.

-- 20_region_topline: Redshift-side (via federation; Redshift AVG truncates
-- at scale 2 on table data -> replicate with FLOOR) vs converted output.
(SELECT region, COUNT(*) AS customers,
        CAST(SUM(lifetime_revenue) AS DECIMAL(38,2)) AS revenue,
        CAST(FLOOR(SUM(avg_order_value) * 100 / COUNT(*)) / 100 AS DECIMAL(38,2)) AS aov
 FROM redshift_src.mart.customer_ltv GROUP BY region)
EXCEPT
(SELECT region, COUNT(*),
        CAST(SUM(lifetime_revenue) AS DECIMAL(38,2)),
        CAST(FLOOR(SUM(avg_order_value) * 100 / COUNT(*)) / 100 AS DECIMAL(38,2))
 FROM migration_demo.mart.customer_ltv GROUP BY region);

-- 20_region_topline: rows only on Databricks
(SELECT region, COUNT(*) AS customers,
        CAST(SUM(lifetime_revenue) AS DECIMAL(38,2)) AS revenue,
        CAST(FLOOR(SUM(avg_order_value) * 100 / COUNT(*)) / 100 AS DECIMAL(38,2)) AS aov
 FROM migration_demo.mart.customer_ltv GROUP BY region)
EXCEPT
(SELECT region, COUNT(*),
        CAST(SUM(lifetime_revenue) AS DECIMAL(38,2)),
        CAST(FLOOR(SUM(avg_order_value) * 100 / COUNT(*)) / 100 AS DECIMAL(38,2))
 FROM redshift_src.mart.customer_ltv GROUP BY region);

-- 21_channel_trend: last 30 days, rows only on Redshift
(SELECT order_date, channel_group,
        CAST(SUM(gross_revenue) AS DECIMAL(38,2)) AS revenue,
        SUM(order_count) AS orders
 FROM redshift_src.mart.daily_revenue
 WHERE order_date >= date_add(current_date(), -30)
 GROUP BY order_date, channel_group)
EXCEPT
(SELECT order_date, channel_group,
        CAST(SUM(gross_revenue) AS DECIMAL(38,2)),
        SUM(order_count)
 FROM migration_demo.mart.daily_revenue
 WHERE order_date >= date_add(current_date(), -30)
 GROUP BY order_date, channel_group);

-- 21_channel_trend: last 30 days, rows only on Databricks
(SELECT order_date, channel_group,
        CAST(SUM(gross_revenue) AS DECIMAL(38,2)) AS revenue,
        SUM(order_count) AS orders
 FROM migration_demo.mart.daily_revenue
 WHERE order_date >= date_add(current_date(), -30)
 GROUP BY order_date, channel_group)
EXCEPT
(SELECT order_date, channel_group,
        CAST(SUM(gross_revenue) AS DECIMAL(38,2)),
        SUM(order_count)
 FROM redshift_src.mart.daily_revenue
 WHERE order_date >= date_add(current_date(), -30)
 GROUP BY order_date, channel_group);
