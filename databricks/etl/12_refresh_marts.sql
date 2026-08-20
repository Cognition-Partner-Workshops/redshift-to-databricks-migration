-- Nightly refresh entry point. Replaces the Redshift stored procedure
-- mart.sp_refresh_marts(); on Databricks the scheduler (Workflows job) runs the
-- mart build files in numeric order instead of a plpgsql wrapper:
--   1. databricks/etl/10_build_daily_revenue.sql
--   2. databricks/etl/11_build_customer_ltv.sql
-- Each build is an atomic CREATE OR REPLACE TABLE, so no staging-table
-- cleanup step is needed.
SELECT 'refresh runs 10_build_daily_revenue.sql then 11_build_customer_ltv.sql' AS refresh_plan;
