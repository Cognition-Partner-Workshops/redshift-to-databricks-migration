-- Nightly mart refresh orchestration.
-- Converted from sql/etl/12_sp_refresh_marts.sql (PL/pgSQL stored procedure).
-- Databricks SQL has no stored procedures; the refresh is a Databricks Job (or SQL task
-- sequence) that runs the mart build steps in numeric order on warehouse 565cd2fd713738c4:
--   1. databricks/etl/10_build_daily_revenue.sql
--   2. databricks/etl/11_build_customer_ltv.sql
-- The legacy procedure only logged start/finish and dropped a stage table that no step
-- creates; both are no-ops in the target and are intentionally not carried over.

DROP TABLE IF EXISTS migration_demo.mart.daily_revenue_stage;
