-- BI report (Databricks SQL): region topline (consumed by the exec dashboard)
--
-- Conversion notes:
--   * AVG(NUMERIC(38,2)): Redshift TRUNCATES the quotient at scale 2 on
--     table data; Databricks AVG rounds at scale 6 -> truncate explicitly
--     (values >= 0, so FLOOR == truncation).
SELECT
    region,
    COUNT(*)                                    AS customers,
    CAST(SUM(lifetime_revenue) AS DECIMAL(38,2)) AS revenue,
    CAST(FLOOR(SUM(avg_order_value) * 100 / COUNT(*))
         / 100 AS DECIMAL(38,2))                 AS aov
FROM migration_demo.mart.customer_ltv
GROUP BY region
ORDER BY revenue DESC;
