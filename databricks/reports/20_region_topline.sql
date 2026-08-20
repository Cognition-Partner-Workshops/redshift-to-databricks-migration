-- BI report: region topline (consumed by the exec dashboard)
-- aov: Redshift AVG over DECIMAL(38,2) truncates the quotient to 2 decimals
-- (Databricks AVG rounds), so truncate explicitly to keep report parity.
SELECT
    region,
    COUNT(*)                    AS customers,
    SUM(lifetime_revenue)       AS revenue,
    CAST(FLOOR(SUM(avg_order_value) / COUNT(avg_order_value) * 100) / 100
         AS DECIMAL(38,2))      AS aov
FROM migration_demo.mart.customer_ltv
GROUP BY region
ORDER BY revenue DESC;
