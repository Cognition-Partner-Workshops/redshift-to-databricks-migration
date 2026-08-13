-- BI report: region topline (consumed by the exec dashboard)
-- Converted from Redshift: AVG(DECIMAL) truncates toward zero at the argument
-- scale (2) on Redshift, while Databricks rounds -- sign(x) * floor(abs(x), 2)
-- reproduces the toward-zero truncation for any sign.
SELECT
    region,
    COUNT(*)                    AS customers,
    SUM(lifetime_revenue)       AS revenue,
    CAST(SIGN(AVG(avg_order_value)) * FLOOR(ABS(AVG(avg_order_value)), 2)
         AS DECIMAL(38,2)) AS aov
FROM migration_demo.mart.customer_ltv
GROUP BY region
ORDER BY revenue DESC;
