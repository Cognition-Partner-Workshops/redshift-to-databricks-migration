#!/usr/bin/env bash
# Export the six Trino source tables to CSV for the Databricks load.
set -euo pipefail
cd /home/ubuntu/repos/redshift-to-databricks-migration/trino
OUT=/home/ubuntu/demo/export
mkdir -p "$OUT"

run() { docker compose exec -T trino trino --output-format=CSV_HEADER --execute "$1"; }

run "SELECT order_id, customer_id, CAST(order_ts AS VARCHAR) AS order_ts, order_status, CAST(order_total AS VARCHAR) AS order_total, sales_channel, json_format(CAST(attrs AS JSON)) AS attrs_json, CAST(order_date AS VARCHAR) AS order_date FROM lake.core.orders ORDER BY order_id" > "$OUT/orders.csv"

run "SELECT order_item_id, order_id, sku, quantity, CAST(unit_price AS VARCHAR) AS unit_price, CAST(discount_pct AS VARCHAR) AS discount_pct FROM lake.core.order_items ORDER BY order_item_id" > "$OUT/order_items.csv"

run "SELECT customer_id, customer_code, full_name, email, region, CAST(signup_date AS VARCHAR) AS signup_date, is_active, CAST(created_at AS VARCHAR) AS created_at FROM ops.public.customers ORDER BY customer_id" > "$OUT/customers.csv"

run "SELECT customer_id, tag FROM ops.public.customer_tags ORDER BY customer_id, tag" > "$OUT/customer_tags.csv"

run "SELECT CAST(order_date AS VARCHAR) AS order_date, region, promo_group, order_count, CAST(gross_revenue AS VARCHAR) AS gross_revenue, CAST(avg_order_value AS VARCHAR) AS avg_order_value FROM lake.mart.daily_revenue ORDER BY order_date, region, promo_group" > "$OUT/daily_revenue.csv"

run "SELECT customer_id, customer_code, region, CAST(first_order_ts AS VARCHAR) AS first_order_ts, CAST(last_order_ts AS VARCHAR) AS last_order_ts, lifetime_orders, CAST(lifetime_revenue AS VARCHAR) AS lifetime_revenue, CAST(avg_order_value AS VARCHAR) AS avg_order_value, active_days, first_order_month, json_format(CAST(tags AS JSON)) AS tags_json FROM lake.mart.customer_ltv ORDER BY customer_id" > "$OUT/customer_ltv.csv"

wc -l "$OUT"/*.csv
