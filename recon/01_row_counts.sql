-- Reconciliation: row counts, Databricks marts vs live Redshift marts via
-- Lakehouse Federation. Run on the Databricks SQL warehouse.
SELECT 'daily_revenue' AS mart,
       (SELECT COUNT(*) FROM redshift_src.mart.daily_revenue)   AS redshift_rows,
       (SELECT COUNT(*) FROM migration_demo.mart.daily_revenue) AS databricks_rows
UNION ALL
SELECT 'customer_ltv',
       (SELECT COUNT(*) FROM redshift_src.mart.customer_ltv),
       (SELECT COUNT(*) FROM migration_demo.mart.customer_ltv);
