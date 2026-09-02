-- BI report: region topline (consumed by the exec dashboard)
-- Converted from sql/reports/20_region_topline.sql.
-- AVG(NUMERIC(38,2)) in Redshift truncates to scale 2; reproduced with FLOOR(SUM/COUNT, 2).
SELECT
    region,
    COUNT(*)                                            AS customers,
    CAST(SUM(lifetime_revenue) AS DECIMAL(38,2))        AS revenue,
    CAST(FLOOR(SUM(avg_order_value) / COUNT(avg_order_value), 2) AS DECIMAL(38,2)) AS aov
FROM migration_demo.mart.customer_ltv
GROUP BY region
ORDER BY revenue DESC;
