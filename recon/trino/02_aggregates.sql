-- Per-column aggregates: every numeric column summed/min/max, every timestamp min/max,
-- every string column distinct count + hashed. Each row must have verdict = PASS.
WITH t AS (
    SELECT 'core.orders' AS object, 'order_id' AS metric,
           CAST(sum(order_id) AS STRING) AS trino_v FROM trino_migration_demo.trino_src.core_orders
    UNION ALL SELECT 'core.orders', 'customer_id_sum', CAST(sum(customer_id) AS STRING) FROM trino_migration_demo.trino_src.core_orders
    UNION ALL SELECT 'core.orders', 'order_ts_min', CAST(min(order_ts) AS STRING) FROM trino_migration_demo.trino_src.core_orders
    UNION ALL SELECT 'core.orders', 'order_ts_max', CAST(max(order_ts) AS STRING) FROM trino_migration_demo.trino_src.core_orders
    UNION ALL SELECT 'core.orders', 'order_status', CAST(xxhash64(concat_ws(',', sort_array(collect_list(order_status)))) AS STRING) FROM trino_migration_demo.trino_src.core_orders
    UNION ALL SELECT 'core.orders', 'order_total_sum', CAST(sum(order_total) AS STRING) FROM trino_migration_demo.trino_src.core_orders
    UNION ALL SELECT 'core.orders', 'sales_channel', CAST(xxhash64(concat_ws(',', sort_array(collect_list(sales_channel)))) AS STRING) FROM trino_migration_demo.trino_src.core_orders
    UNION ALL SELECT 'core.orders', 'attrs', CAST(xxhash64(concat_ws(',', sort_array(collect_list(to_json(map_from_entries(array_sort(map_entries(attrs)))))))) AS STRING) FROM trino_migration_demo.trino_src.core_orders
    UNION ALL SELECT 'core.orders', 'order_date_min', CAST(min(order_date) AS STRING) FROM trino_migration_demo.trino_src.core_orders
    UNION ALL SELECT 'core.orders', 'order_date_max', CAST(max(order_date) AS STRING) FROM trino_migration_demo.trino_src.core_orders

    UNION ALL SELECT 'core.order_items', 'order_item_id_sum', CAST(sum(order_item_id) AS STRING) FROM trino_migration_demo.trino_src.core_order_items
    UNION ALL SELECT 'core.order_items', 'order_id_sum', CAST(sum(order_id) AS STRING) FROM trino_migration_demo.trino_src.core_order_items
    UNION ALL SELECT 'core.order_items', 'sku', CAST(xxhash64(concat_ws(',', sort_array(collect_list(sku)))) AS STRING) FROM trino_migration_demo.trino_src.core_order_items
    UNION ALL SELECT 'core.order_items', 'quantity_sum', CAST(sum(quantity) AS STRING) FROM trino_migration_demo.trino_src.core_order_items
    UNION ALL SELECT 'core.order_items', 'unit_price_sum', CAST(sum(unit_price) AS STRING) FROM trino_migration_demo.trino_src.core_order_items
    UNION ALL SELECT 'core.order_items', 'discount_pct_sum', CAST(sum(discount_pct) AS STRING) FROM trino_migration_demo.trino_src.core_order_items

    UNION ALL SELECT 'ops.customers', 'customer_id_sum', CAST(sum(customer_id) AS STRING) FROM trino_migration_demo.trino_src.ops_customers
    UNION ALL SELECT 'ops.customers', 'customer_code', CAST(xxhash64(concat_ws(',', sort_array(collect_list(concat('[', customer_code, ']'))))) AS STRING) FROM trino_migration_demo.trino_src.ops_customers
    UNION ALL SELECT 'ops.customers', 'full_name', CAST(xxhash64(concat_ws(',', sort_array(collect_list(full_name)))) AS STRING) FROM trino_migration_demo.trino_src.ops_customers
    UNION ALL SELECT 'ops.customers', 'email', CAST(xxhash64(concat_ws(',', sort_array(collect_list(email)))) AS STRING) FROM trino_migration_demo.trino_src.ops_customers
    UNION ALL SELECT 'ops.customers', 'region', CAST(xxhash64(concat_ws(',', sort_array(collect_list(concat('[', region, ']'))))) AS STRING) FROM trino_migration_demo.trino_src.ops_customers
    UNION ALL SELECT 'ops.customers', 'signup_date_min', CAST(min(signup_date) AS STRING) FROM trino_migration_demo.trino_src.ops_customers
    UNION ALL SELECT 'ops.customers', 'signup_date_max', CAST(max(signup_date) AS STRING) FROM trino_migration_demo.trino_src.ops_customers
    UNION ALL SELECT 'ops.customers', 'is_active_true', CAST(count_if(is_active) AS STRING) FROM trino_migration_demo.trino_src.ops_customers
    UNION ALL SELECT 'ops.customers', 'created_at_min', CAST(min(created_at) AS STRING) FROM trino_migration_demo.trino_src.ops_customers
    UNION ALL SELECT 'ops.customers', 'created_at_max', CAST(max(created_at) AS STRING) FROM trino_migration_demo.trino_src.ops_customers

    UNION ALL SELECT 'ops.customer_tags', 'customer_id_sum', CAST(sum(customer_id) AS STRING) FROM trino_migration_demo.trino_src.ops_customer_tags
    UNION ALL SELECT 'ops.customer_tags', 'tag', CAST(xxhash64(concat_ws(',', sort_array(collect_list(concat(customer_id, ':', tag))))) AS STRING) FROM trino_migration_demo.trino_src.ops_customer_tags

    UNION ALL SELECT 'mart.daily_revenue', 'order_date_min', CAST(min(order_date) AS STRING) FROM trino_migration_demo.trino_src.mart_daily_revenue
    UNION ALL SELECT 'mart.daily_revenue', 'order_date_max', CAST(max(order_date) AS STRING) FROM trino_migration_demo.trino_src.mart_daily_revenue
    UNION ALL SELECT 'mart.daily_revenue', 'region', CAST(xxhash64(concat_ws(',', sort_array(collect_list(concat('[', region, ']'))))) AS STRING) FROM trino_migration_demo.trino_src.mart_daily_revenue
    UNION ALL SELECT 'mart.daily_revenue', 'promo_group', CAST(xxhash64(concat_ws(',', sort_array(collect_list(promo_group)))) AS STRING) FROM trino_migration_demo.trino_src.mart_daily_revenue
    UNION ALL SELECT 'mart.daily_revenue', 'order_count_sum', CAST(sum(order_count) AS STRING) FROM trino_migration_demo.trino_src.mart_daily_revenue
    UNION ALL SELECT 'mart.daily_revenue', 'gross_revenue_sum', CAST(sum(gross_revenue) AS STRING) FROM trino_migration_demo.trino_src.mart_daily_revenue
    UNION ALL SELECT 'mart.daily_revenue', 'avg_order_value_sum', CAST(sum(avg_order_value) AS STRING) FROM trino_migration_demo.trino_src.mart_daily_revenue

    UNION ALL SELECT 'mart.customer_ltv', 'customer_id_sum', CAST(sum(customer_id) AS STRING) FROM trino_migration_demo.trino_src.mart_customer_ltv
    UNION ALL SELECT 'mart.customer_ltv', 'customer_code', CAST(xxhash64(concat_ws(',', sort_array(collect_list(concat('[', customer_code, ']'))))) AS STRING) FROM trino_migration_demo.trino_src.mart_customer_ltv
    UNION ALL SELECT 'mart.customer_ltv', 'region', CAST(xxhash64(concat_ws(',', sort_array(collect_list(concat('[', region, ']'))))) AS STRING) FROM trino_migration_demo.trino_src.mart_customer_ltv
    UNION ALL SELECT 'mart.customer_ltv', 'first_order_ts_min', CAST(min(first_order_ts) AS STRING) FROM trino_migration_demo.trino_src.mart_customer_ltv
    UNION ALL SELECT 'mart.customer_ltv', 'last_order_ts_max', CAST(max(last_order_ts) AS STRING) FROM trino_migration_demo.trino_src.mart_customer_ltv
    UNION ALL SELECT 'mart.customer_ltv', 'lifetime_orders_sum', CAST(sum(lifetime_orders) AS STRING) FROM trino_migration_demo.trino_src.mart_customer_ltv
    UNION ALL SELECT 'mart.customer_ltv', 'lifetime_revenue_sum', CAST(sum(lifetime_revenue) AS STRING) FROM trino_migration_demo.trino_src.mart_customer_ltv
    UNION ALL SELECT 'mart.customer_ltv', 'avg_order_value_sum', CAST(sum(avg_order_value) AS STRING) FROM trino_migration_demo.trino_src.mart_customer_ltv
    UNION ALL SELECT 'mart.customer_ltv', 'active_days_sum', CAST(sum(active_days) AS STRING) FROM trino_migration_demo.trino_src.mart_customer_ltv
    UNION ALL SELECT 'mart.customer_ltv', 'first_order_month', CAST(xxhash64(concat_ws(',', sort_array(collect_list(first_order_month)))) AS STRING) FROM trino_migration_demo.trino_src.mart_customer_ltv
    UNION ALL SELECT 'mart.customer_ltv', 'tags', CAST(xxhash64(concat_ws(',', sort_array(collect_list(concat(customer_id, ':', to_json(tags)))))) AS STRING) FROM trino_migration_demo.trino_src.mart_customer_ltv
),
d AS (
    SELECT 'core.orders' AS object, 'order_id' AS metric,
           CAST(sum(order_id) AS STRING) AS dbx_v FROM trino_migration_demo.core.orders
    UNION ALL SELECT 'core.orders', 'customer_id_sum', CAST(sum(customer_id) AS STRING) FROM trino_migration_demo.core.orders
    UNION ALL SELECT 'core.orders', 'order_ts_min', CAST(min(order_ts) AS STRING) FROM trino_migration_demo.core.orders
    UNION ALL SELECT 'core.orders', 'order_ts_max', CAST(max(order_ts) AS STRING) FROM trino_migration_demo.core.orders
    UNION ALL SELECT 'core.orders', 'order_status', CAST(xxhash64(concat_ws(',', sort_array(collect_list(order_status)))) AS STRING) FROM trino_migration_demo.core.orders
    UNION ALL SELECT 'core.orders', 'order_total_sum', CAST(sum(order_total) AS STRING) FROM trino_migration_demo.core.orders
    UNION ALL SELECT 'core.orders', 'sales_channel', CAST(xxhash64(concat_ws(',', sort_array(collect_list(sales_channel)))) AS STRING) FROM trino_migration_demo.core.orders
    UNION ALL SELECT 'core.orders', 'attrs', CAST(xxhash64(concat_ws(',', sort_array(collect_list(to_json(map_from_entries(array_sort(map_entries(attrs)))))))) AS STRING) FROM trino_migration_demo.core.orders
    UNION ALL SELECT 'core.orders', 'order_date_min', CAST(min(order_date) AS STRING) FROM trino_migration_demo.core.orders
    UNION ALL SELECT 'core.orders', 'order_date_max', CAST(max(order_date) AS STRING) FROM trino_migration_demo.core.orders

    UNION ALL SELECT 'core.order_items', 'order_item_id_sum', CAST(sum(order_item_id) AS STRING) FROM trino_migration_demo.core.order_items
    UNION ALL SELECT 'core.order_items', 'order_id_sum', CAST(sum(order_id) AS STRING) FROM trino_migration_demo.core.order_items
    UNION ALL SELECT 'core.order_items', 'sku', CAST(xxhash64(concat_ws(',', sort_array(collect_list(sku)))) AS STRING) FROM trino_migration_demo.core.order_items
    UNION ALL SELECT 'core.order_items', 'quantity_sum', CAST(sum(quantity) AS STRING) FROM trino_migration_demo.core.order_items
    UNION ALL SELECT 'core.order_items', 'unit_price_sum', CAST(sum(unit_price) AS STRING) FROM trino_migration_demo.core.order_items
    UNION ALL SELECT 'core.order_items', 'discount_pct_sum', CAST(sum(discount_pct) AS STRING) FROM trino_migration_demo.core.order_items

    UNION ALL SELECT 'ops.customers', 'customer_id_sum', CAST(sum(customer_id) AS STRING) FROM trino_migration_demo.ops.customers
    UNION ALL SELECT 'ops.customers', 'customer_code', CAST(xxhash64(concat_ws(',', sort_array(collect_list(concat('[', customer_code, ']'))))) AS STRING) FROM trino_migration_demo.ops.customers
    UNION ALL SELECT 'ops.customers', 'full_name', CAST(xxhash64(concat_ws(',', sort_array(collect_list(full_name)))) AS STRING) FROM trino_migration_demo.ops.customers
    UNION ALL SELECT 'ops.customers', 'email', CAST(xxhash64(concat_ws(',', sort_array(collect_list(email)))) AS STRING) FROM trino_migration_demo.ops.customers
    UNION ALL SELECT 'ops.customers', 'region', CAST(xxhash64(concat_ws(',', sort_array(collect_list(concat('[', region, ']'))))) AS STRING) FROM trino_migration_demo.ops.customers
    UNION ALL SELECT 'ops.customers', 'signup_date_min', CAST(min(signup_date) AS STRING) FROM trino_migration_demo.ops.customers
    UNION ALL SELECT 'ops.customers', 'signup_date_max', CAST(max(signup_date) AS STRING) FROM trino_migration_demo.ops.customers
    UNION ALL SELECT 'ops.customers', 'is_active_true', CAST(count_if(is_active) AS STRING) FROM trino_migration_demo.ops.customers
    UNION ALL SELECT 'ops.customers', 'created_at_min', CAST(min(created_at) AS STRING) FROM trino_migration_demo.ops.customers
    UNION ALL SELECT 'ops.customers', 'created_at_max', CAST(max(created_at) AS STRING) FROM trino_migration_demo.ops.customers

    UNION ALL SELECT 'ops.customer_tags', 'customer_id_sum', CAST(sum(customer_id) AS STRING) FROM trino_migration_demo.ops.customer_tags
    UNION ALL SELECT 'ops.customer_tags', 'tag', CAST(xxhash64(concat_ws(',', sort_array(collect_list(concat(customer_id, ':', tag))))) AS STRING) FROM trino_migration_demo.ops.customer_tags

    UNION ALL SELECT 'mart.daily_revenue', 'order_date_min', CAST(min(order_date) AS STRING) FROM trino_migration_demo.mart.daily_revenue
    UNION ALL SELECT 'mart.daily_revenue', 'order_date_max', CAST(max(order_date) AS STRING) FROM trino_migration_demo.mart.daily_revenue
    UNION ALL SELECT 'mart.daily_revenue', 'region', CAST(xxhash64(concat_ws(',', sort_array(collect_list(concat('[', region, ']'))))) AS STRING) FROM trino_migration_demo.mart.daily_revenue
    UNION ALL SELECT 'mart.daily_revenue', 'promo_group', CAST(xxhash64(concat_ws(',', sort_array(collect_list(promo_group)))) AS STRING) FROM trino_migration_demo.mart.daily_revenue
    UNION ALL SELECT 'mart.daily_revenue', 'order_count_sum', CAST(sum(order_count) AS STRING) FROM trino_migration_demo.mart.daily_revenue
    UNION ALL SELECT 'mart.daily_revenue', 'gross_revenue_sum', CAST(sum(gross_revenue) AS STRING) FROM trino_migration_demo.mart.daily_revenue
    UNION ALL SELECT 'mart.daily_revenue', 'avg_order_value_sum', CAST(sum(avg_order_value) AS STRING) FROM trino_migration_demo.mart.daily_revenue

    UNION ALL SELECT 'mart.customer_ltv', 'customer_id_sum', CAST(sum(customer_id) AS STRING) FROM trino_migration_demo.mart.customer_ltv
    UNION ALL SELECT 'mart.customer_ltv', 'customer_code', CAST(xxhash64(concat_ws(',', sort_array(collect_list(concat('[', customer_code, ']'))))) AS STRING) FROM trino_migration_demo.mart.customer_ltv
    UNION ALL SELECT 'mart.customer_ltv', 'region', CAST(xxhash64(concat_ws(',', sort_array(collect_list(concat('[', region, ']'))))) AS STRING) FROM trino_migration_demo.mart.customer_ltv
    UNION ALL SELECT 'mart.customer_ltv', 'first_order_ts_min', CAST(min(first_order_ts) AS STRING) FROM trino_migration_demo.mart.customer_ltv
    UNION ALL SELECT 'mart.customer_ltv', 'last_order_ts_max', CAST(max(last_order_ts) AS STRING) FROM trino_migration_demo.mart.customer_ltv
    UNION ALL SELECT 'mart.customer_ltv', 'lifetime_orders_sum', CAST(sum(lifetime_orders) AS STRING) FROM trino_migration_demo.mart.customer_ltv
    UNION ALL SELECT 'mart.customer_ltv', 'lifetime_revenue_sum', CAST(sum(lifetime_revenue) AS STRING) FROM trino_migration_demo.mart.customer_ltv
    UNION ALL SELECT 'mart.customer_ltv', 'avg_order_value_sum', CAST(sum(avg_order_value) AS STRING) FROM trino_migration_demo.mart.customer_ltv
    UNION ALL SELECT 'mart.customer_ltv', 'active_days_sum', CAST(sum(active_days) AS STRING) FROM trino_migration_demo.mart.customer_ltv
    UNION ALL SELECT 'mart.customer_ltv', 'first_order_month', CAST(xxhash64(concat_ws(',', sort_array(collect_list(first_order_month)))) AS STRING) FROM trino_migration_demo.mart.customer_ltv
    UNION ALL SELECT 'mart.customer_ltv', 'tags', CAST(xxhash64(concat_ws(',', sort_array(collect_list(concat(customer_id, ':', to_json(tags)))))) AS STRING) FROM trino_migration_demo.mart.customer_ltv
)
SELECT t.object, t.metric, t.trino_v, d.dbx_v,
       IF(t.trino_v <=> d.dbx_v, 'PASS', 'FAIL') AS verdict
FROM t JOIN d ON t.object = d.object AND t.metric = d.metric
ORDER BY verdict, t.object, t.metric;
