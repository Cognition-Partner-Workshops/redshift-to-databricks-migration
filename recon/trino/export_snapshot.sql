-- Trino-side snapshot export. Each statement is run with
--   trino --output-format CSV_HEADER --execute "<stmt>" > docs/evidence/run-2/snapshot/<object>.csv
-- Types are made lossless for CSV: MAP -> JSON text, TIMESTAMP(3) kept as text with millis,
-- CHAR columns exported verbatim (trailing padding preserved by quoting).

-- lake.core.orders
SELECT order_id, customer_id,
       CAST(order_ts AS VARCHAR) AS order_ts,
       order_status, order_total, sales_channel,
       json_format(CAST(attrs AS JSON)) AS attrs,
       CAST(order_date AS VARCHAR) AS order_date
FROM lake.core.orders ORDER BY order_id;

-- lake.core.order_items
SELECT order_item_id, order_id, sku, quantity, unit_price, discount_pct
FROM lake.core.order_items ORDER BY order_item_id;

-- ops.public.customers
SELECT customer_id, customer_code, full_name, email, region,
       CAST(signup_date AS VARCHAR) AS signup_date, is_active,
       CAST(created_at AS VARCHAR) AS created_at
FROM ops.public.customers ORDER BY customer_id;

-- ops.public.customer_tags
SELECT customer_id, tag FROM ops.public.customer_tags ORDER BY customer_id, tag;

-- lake.mart.daily_revenue
SELECT CAST(order_date AS VARCHAR) AS order_date, region, promo_group, order_count,
       gross_revenue, avg_order_value
FROM lake.mart.daily_revenue ORDER BY order_date, region, promo_group;

-- lake.mart.customer_ltv
SELECT customer_id, customer_code, region,
       CAST(first_order_ts AS VARCHAR) AS first_order_ts,
       CAST(last_order_ts AS VARCHAR) AS last_order_ts,
       lifetime_orders, lifetime_revenue, avg_order_value, active_days, first_order_month,
       json_format(CAST(tags AS JSON)) AS tags
FROM lake.mart.customer_ltv ORDER BY customer_id;
