-- BI report: region topline (consumed by the exec dashboard).
-- Translated from sql/reports/20_region_topline.sql, reads the gold mart.
-- aov is the mean of the per-customer avg_order_value in the region. Redshift
-- AVG over DECIMAL(38,2) truncates at 2 decimals, so the same truncating mean
-- (SUM / COUNT through avg_order_value) is used here to keep the report identical.
SELECT
    region,
    COUNT(*)                                            AS customers,
    CAST(SUM(lifetime_revenue) AS DECIMAL(38,2))        AS revenue,
    CAST(migration_demo.silver.avg_order_value(
        CAST(SUM(avg_order_value) AS DECIMAL(38,2)),
        COUNT(avg_order_value),
        2) AS DECIMAL(38,2))                            AS aov
FROM migration_demo.mart.customer_ltv
GROUP BY region
ORDER BY revenue DESC;
