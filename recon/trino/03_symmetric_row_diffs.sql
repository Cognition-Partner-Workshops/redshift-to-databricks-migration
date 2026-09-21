-- Symmetric row diffs: full-row EXCEPT in both directions for both marts.
-- All four counts must be 0. Arrays and CHAR columns are compared as-is, so a
-- different tag order or a lost blank pad shows up here.
SELECT 'daily_revenue: in Trino, not in Databricks' AS direction, count(*) AS rows FROM (
  SELECT * FROM trino_migration_demo_run4.trino_src.daily_revenue
  EXCEPT
  SELECT * FROM trino_migration_demo_run4.mart.daily_revenue)
UNION ALL
SELECT 'daily_revenue: in Databricks, not in Trino', count(*) FROM (
  SELECT * FROM trino_migration_demo_run4.mart.daily_revenue
  EXCEPT
  SELECT * FROM trino_migration_demo_run4.trino_src.daily_revenue)
UNION ALL
SELECT 'customer_ltv: in Trino, not in Databricks', count(*) FROM (
  SELECT * FROM trino_migration_demo_run4.trino_src.customer_ltv
  EXCEPT
  SELECT * FROM trino_migration_demo_run4.mart.customer_ltv)
UNION ALL
SELECT 'customer_ltv: in Databricks, not in Trino', count(*) FROM (
  SELECT * FROM trino_migration_demo_run4.mart.customer_ltv
  EXCEPT
  SELECT * FROM trino_migration_demo_run4.trino_src.customer_ltv)
ORDER BY direction
