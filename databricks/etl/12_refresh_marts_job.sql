-- Nightly mart refresh entry point.
-- Replaces the Redshift stored procedure mart.sp_refresh_marts() (plpgsql),
-- which only logged start/finish and relied on the scheduler running the
-- numbered build steps in order. On Databricks the scheduler (job task)
-- runs the build files directly, in numeric order:
--   1. databricks/etl/10_build_daily_revenue.sql
--   2. databricks/etl/11_build_customer_ltv.sql
SELECT current_timestamp() AS refresh_started_at;
