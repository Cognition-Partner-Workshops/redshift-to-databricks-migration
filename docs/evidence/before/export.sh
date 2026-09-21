#!/bin/sh
# Export the six Trino tables to CSV (maps/arrays as JSON text) for landing in a UC volume.
set -e
cd /home/ubuntu/trino-estate/trino
OUT=/home/ubuntu/export/csv
mkdir -p "$OUT"
run() { docker compose exec -T trino trino --output-format CSV_HEADER --execute "$2" > "$OUT/$1.csv"; wc -l "$OUT/$1.csv"; }

run core_orders "SELECT order_id, customer_id, order_ts, order_status, order_total, sales_channel, json_format(CAST(attrs AS JSON)) AS attrs, order_date FROM lake.core.orders ORDER BY order_id"
run core_order_items "SELECT order_item_id, order_id, sku, quantity, unit_price, discount_pct FROM lake.core.order_items ORDER BY order_item_id"
run ops_customers "SELECT customer_id, customer_code, full_name, email, region, signup_date, is_active, created_at FROM ops.public.customers ORDER BY customer_id"
run ops_customer_tags "SELECT customer_id, tag FROM ops.public.customer_tags ORDER BY customer_id, tag"
run mart_daily_revenue "SELECT order_date, region, promo_group, order_count, gross_revenue, avg_order_value FROM lake.mart.daily_revenue ORDER BY order_date, region, promo_group"
run mart_customer_ltv "SELECT customer_id, customer_code, region, first_order_ts, last_order_ts, lifetime_orders, lifetime_revenue, avg_order_value, active_days, first_order_month, json_format(CAST(tags AS JSON)) AS tags FROM lake.mart.customer_ltv ORDER BY customer_id"
