-- BI report: region topline (consumed by the exec dashboard)
-- Converted from Redshift: AVG(DECIMAL) truncates at the argument scale (2)
-- on Redshift, while Databricks rounds -- floor(x, 2) preserves the legacy output.
SELECT
    region,
    COUNT(*)                    AS customers,
    SUM(lifetime_revenue)       AS revenue,
    CAST(FLOOR(AVG(avg_order_value), 2) AS DECIMAL(38,2)) AS aov
FROM migration_demo.mart.customer_ltv
GROUP BY region
ORDER BY revenue DESC;
