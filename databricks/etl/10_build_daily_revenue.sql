-- Gold: mart.daily_revenue, one row per (order_date, region, channel_group)
-- for completed days. Translated from sql/etl/10_build_daily_revenue.sql.
--
-- The join, cancelled filter, TRUNC(order_ts) and DECODE now live in
-- silver.enriched_orders. What remains here is the daily grain, the
-- "completed days only" cut (order_ts < TRUNC(GETDATE()) -> order_date < current_date();
-- the warehouse runs in UTC like Redshift), and the canonical avg_order_value at
-- 4 decimals (Redshift published this mart's AOV as DECIMAL(38,4)).
--
-- CREATE OR REPLACE TABLE swaps the table atomically (readers never see a missing
-- table, previous versions stay available via Delta time travel) and keeps the
-- table's grants, unlike DROP + CTAS. DISTSTYLE ALL / SORTKEY -> CLUSTER BY.

CREATE OR REPLACE TABLE migration_demo.mart.daily_revenue
CLUSTER BY (order_date)
COMMENT 'Daily gross revenue, order count and AOV by region and channel group, completed days only'
AS
SELECT
    e.order_date,
    e.region,
    e.channel_group,
    COUNT(DISTINCT e.order_id)                          AS order_count,
    CAST(SUM(e.order_total) AS DECIMAL(38,2))           AS gross_revenue,
    migration_demo.silver.avg_order_value(
        CAST(SUM(e.order_total) AS DECIMAL(38,2)),
        COUNT(DISTINCT e.order_id),
        4)                                              AS avg_order_value
FROM migration_demo.silver.enriched_orders e
WHERE e.order_date < current_date()
GROUP BY e.order_date, e.region, e.channel_group;
