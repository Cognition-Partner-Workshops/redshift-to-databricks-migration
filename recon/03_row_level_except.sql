-- Reconciliation: row-level EXCEPT diffs in both directions for both marts.
-- All four queries must return 0 rows for a green reconciliation.
-- Values are compared at the Redshift storage scale (gross/lifetime revenue
-- DECIMAL(38,2); daily avg_order_value DECIMAL(38,4); ltv avg DECIMAL(38,2)).
-- Run on the Databricks SQL warehouse.

-- daily_revenue: rows in Redshift missing from Databricks
(SELECT order_date, region, channel_group, order_count,
        CAST(gross_revenue AS DECIMAL(38,2)) AS gross_revenue,
        CAST(avg_order_value AS DECIMAL(38,4)) AS avg_order_value
 FROM redshift_src.mart.daily_revenue
 EXCEPT
 SELECT order_date, region, channel_group, order_count,
        CAST(gross_revenue AS DECIMAL(38,2)),
        CAST(avg_order_value AS DECIMAL(38,4))
 FROM migration_demo.mart.daily_revenue)
LIMIT 20;

-- daily_revenue: rows in Databricks missing from Redshift
(SELECT order_date, region, channel_group, order_count,
        CAST(gross_revenue AS DECIMAL(38,2)) AS gross_revenue,
        CAST(avg_order_value AS DECIMAL(38,4)) AS avg_order_value
 FROM migration_demo.mart.daily_revenue
 EXCEPT
 SELECT order_date, region, channel_group, order_count,
        CAST(gross_revenue AS DECIMAL(38,2)),
        CAST(avg_order_value AS DECIMAL(38,4))
 FROM redshift_src.mart.daily_revenue)
LIMIT 20;

-- customer_ltv: rows in Redshift missing from Databricks
(SELECT customer_id, customer_code, region, first_order_ts, last_order_ts,
        lifetime_orders,
        CAST(lifetime_revenue AS DECIMAL(38,2)) AS lifetime_revenue,
        CAST(avg_order_value AS DECIMAL(38,2)) AS avg_order_value,
        active_days
 FROM redshift_src.mart.customer_ltv
 EXCEPT
 SELECT customer_id, customer_code, region, first_order_ts, last_order_ts,
        lifetime_orders,
        CAST(lifetime_revenue AS DECIMAL(38,2)),
        CAST(avg_order_value AS DECIMAL(38,2)),
        active_days
 FROM migration_demo.mart.customer_ltv)
LIMIT 20;

-- customer_ltv: rows in Databricks missing from Redshift
(SELECT customer_id, customer_code, region, first_order_ts, last_order_ts,
        lifetime_orders,
        CAST(lifetime_revenue AS DECIMAL(38,2)) AS lifetime_revenue,
        CAST(avg_order_value AS DECIMAL(38,2)) AS avg_order_value,
        active_days
 FROM migration_demo.mart.customer_ltv
 EXCEPT
 SELECT customer_id, customer_code, region, first_order_ts, last_order_ts,
        lifetime_orders,
        CAST(lifetime_revenue AS DECIMAL(38,2)),
        CAST(avg_order_value AS DECIMAL(38,2)),
        active_days
 FROM redshift_src.mart.customer_ltv)
LIMIT 20;
