-- BI report: region topline (consumed by the exec dashboard)
-- Converted from sql/reports/20_region_topline.sql.
-- AVG over DECIMAL in Redshift truncates toward zero at the input scale, reproduced here with
-- SUM/COUNT truncated at scale 2.
SELECT
    region,
    COUNT(*)                                            AS customers,
    CAST(SUM(lifetime_revenue) AS DECIMAL(38,2))        AS revenue,
    CAST(CASE WHEN SUM(avg_order_value) < 0
              THEN CEIL(SUM(avg_order_value) / COUNT(avg_order_value), 2)
              ELSE FLOOR(SUM(avg_order_value) / COUNT(avg_order_value), 2)
         END AS DECIMAL(38,2))                          AS aov
FROM migration_demo.mart.customer_ltv
GROUP BY region
ORDER BY revenue DESC;
