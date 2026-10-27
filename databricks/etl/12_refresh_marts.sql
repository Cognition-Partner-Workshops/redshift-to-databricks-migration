-- Replaces the PL/pgSQL procedure mart.sp_refresh_marts (sql/etl/12_sp_refresh_marts.sql).
-- Databricks SQL scripting block with the same body; the mart builds still run from the
-- scheduler in numeric order (10, 11). RAISE INFO is not available, so the start and finish
-- times are returned as the block's result instead.
BEGIN
    DECLARE refresh_started TIMESTAMP DEFAULT current_timestamp();
    DROP TABLE IF EXISTS migration_demo.mart.daily_revenue_stage;
    SELECT refresh_started AS refresh_started, current_timestamp() AS refresh_finished;
END;
