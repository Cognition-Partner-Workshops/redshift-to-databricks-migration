-- Symmetric row-level diffs for the two rebuilt marts (the four landed tables are byte copies of
-- trino_src and are covered by 01/02). Rows are canonicalised to strings so MAP/ARRAY compare.
-- Every *_only count must be 0.
WITH dr_t AS (
    SELECT CAST(order_date AS STRING) AS order_date, concat('[', region, ']') AS region, promo_group,
           order_count, CAST(gross_revenue AS STRING) AS gross_revenue,
           CAST(avg_order_value AS STRING) AS avg_order_value
    FROM trino_migration_demo.trino_src.mart_daily_revenue
),
dr_d AS (
    SELECT CAST(order_date AS STRING) AS order_date, concat('[', region, ']') AS region, promo_group,
           order_count, CAST(gross_revenue AS STRING) AS gross_revenue,
           CAST(avg_order_value AS STRING) AS avg_order_value
    FROM trino_migration_demo.mart.daily_revenue
),
ltv_t AS (
    SELECT customer_id, concat('[', customer_code, ']') AS customer_code, concat('[', region, ']') AS region,
           CAST(first_order_ts AS STRING) AS first_order_ts, CAST(last_order_ts AS STRING) AS last_order_ts,
           lifetime_orders, CAST(lifetime_revenue AS STRING) AS lifetime_revenue,
           CAST(avg_order_value AS STRING) AS avg_order_value, active_days, first_order_month,
           to_json(tags) AS tags
    FROM trino_migration_demo.trino_src.mart_customer_ltv
),
ltv_d AS (
    SELECT customer_id, concat('[', customer_code, ']') AS customer_code, concat('[', region, ']') AS region,
           CAST(first_order_ts AS STRING) AS first_order_ts, CAST(last_order_ts AS STRING) AS last_order_ts,
           lifetime_orders, CAST(lifetime_revenue AS STRING) AS lifetime_revenue,
           CAST(avg_order_value AS STRING) AS avg_order_value, active_days, first_order_month,
           to_json(tags) AS tags
    FROM trino_migration_demo.mart.customer_ltv
)
SELECT 'mart.daily_revenue' AS object,
       (SELECT count(*) FROM (SELECT * FROM dr_t EXCEPT ALL SELECT * FROM dr_d)) AS trino_only,
       (SELECT count(*) FROM (SELECT * FROM dr_d EXCEPT ALL SELECT * FROM dr_t)) AS dbx_only
UNION ALL
SELECT 'mart.customer_ltv',
       (SELECT count(*) FROM (SELECT * FROM ltv_t EXCEPT ALL SELECT * FROM ltv_d)),
       (SELECT count(*) FROM (SELECT * FROM ltv_d EXCEPT ALL SELECT * FROM ltv_t));
