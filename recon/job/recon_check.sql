-- Scheduled reconciliation check: migrated Databricks marts vs live Redshift
-- (via Lakehouse Federation). Runs on the SQL warehouse as a Databricks job
-- task; raises an error (failing the job) if any check is red.

WITH counts AS (
  SELECT 'core.orders' AS obj,
         (SELECT COUNT(*) FROM redshift_src.core.orders)          AS src,
         (SELECT COUNT(*) FROM migration_demo.core.orders)        AS tgt
  UNION ALL
  SELECT 'core.order_items',
         (SELECT COUNT(*) FROM redshift_src.core.order_items),
         (SELECT COUNT(*) FROM migration_demo.core.order_items)
  UNION ALL
  SELECT 'core.customers',
         (SELECT COUNT(*) FROM redshift_src.core.customers),
         (SELECT COUNT(*) FROM migration_demo.core.customers)
  UNION ALL
  SELECT 'mart.daily_revenue',
         (SELECT COUNT(*) FROM redshift_src.mart.daily_revenue),
         (SELECT COUNT(*) FROM migration_demo.mart.daily_revenue)
  UNION ALL
  SELECT 'mart.customer_ltv',
         (SELECT COUNT(*) FROM redshift_src.mart.customer_ltv),
         (SELECT COUNT(*) FROM migration_demo.mart.customer_ltv)
),
aggs AS (
  SELECT 'orders revenue/max_ts' AS obj,
         (SELECT CONCAT(CAST(SUM(order_total) AS STRING), '|', CAST(MAX(order_ts) AS STRING))
            FROM redshift_src.core.orders)   AS src_sig,
         (SELECT CONCAT(CAST(SUM(order_total) AS STRING), '|', CAST(MAX(order_ts) AS STRING))
            FROM migration_demo.core.orders) AS tgt_sig
),
failures AS (
  SELECT CONCAT('ROW COUNT MISMATCH ', obj, ': redshift=', src, ' databricks=', tgt) AS msg
  FROM counts WHERE src <> tgt
  UNION ALL
  SELECT CONCAT('AGGREGATE MISMATCH ', obj, ': redshift=', src_sig, ' databricks=', tgt_sig)
  FROM aggs WHERE src_sig <> tgt_sig
)
SELECT CASE
         WHEN (SELECT COUNT(*) FROM failures) > 0
         THEN raise_error(CONCAT('RECONCILIATION FAILED: ',
                (SELECT concat_ws('; ', collect_list(msg)) FROM failures)))
         ELSE 'RECONCILIATION GREEN: all row counts and aggregates match'
       END AS recon_result;
