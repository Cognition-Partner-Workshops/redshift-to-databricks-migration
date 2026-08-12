-- Aggregate parity to the cent.
SELECT 'orders.order_total' AS metric,
       (SELECT SUM(order_total)  FROM redshift_src.core.orders)   AS src_sum,
       (SELECT SUM(order_total)  FROM migration_demo.core.orders) AS tgt_sum,
       (SELECT MAX(order_ts)     FROM redshift_src.core.orders)   AS src_max_ts,
       (SELECT MAX(order_ts)     FROM migration_demo.core.orders) AS tgt_max_ts;

-- The semantic trap: AVG over DECIMAL. Redshift truncates result scale,
-- Databricks rounds — any naive conversion diverges by one cent on ~half of rows.
SELECT COUNT(*) AS avg_mismatch_rows
FROM redshift_src.mart.customer_ltv s
JOIN migration_demo.mart.customer_ltv t USING (customer_id)
WHERE s.avg_order_value <> t.avg_order_value;
