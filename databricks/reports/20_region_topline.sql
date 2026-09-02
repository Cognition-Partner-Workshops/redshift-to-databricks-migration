-- BI report: region topline (consumed by the exec dashboard)
-- Converted from sql/reports/20_region_topline.sql.
-- AVG(NUMERIC(38,2)) in Redshift truncates toward zero at scale 2; reproduced with SUM/COUNT
-- truncated toward zero (FLOOR for non-negative, CEIL for negative).
SELECT
    region,
    COUNT(*)                                            AS customers,
    CAST(SUM(lifetime_revenue) AS DECIMAL(38,2))        AS revenue,
    CAST(CASE WHEN SUM(avg_order_value) < 0
              THEN CEIL(SUM(avg_order_value) / COUNT(avg_order_value), 2)
              ELSE FLOOR(SUM(avg_order_value) / COUNT(avg_order_value), 2)
         END AS DECIMAL(38,2))                             AS aov
FROM migration_demo.mart.customer_ltv
GROUP BY region
ORDER BY revenue DESC;
