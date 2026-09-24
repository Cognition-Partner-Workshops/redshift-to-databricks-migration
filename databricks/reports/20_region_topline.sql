-- BI report: region topline (consumed by the exec dashboard)
-- Converted from sql/reports/20_region_topline.sql (Redshift).
--   * AVG(avg_order_value): Redshift AVG over DECIMAL(38,2) keeps scale 2 and
--     truncates toward zero, Databricks widens and rounds, so truncation is
--     reproduced explicitly and cast to DECIMAL(38,2)
--   * SUM(lifetime_revenue) cast to DECIMAL(38,2) to match the Redshift type
SELECT
    region,
    COUNT(*)                                                            AS customers,
    CAST(SUM(lifetime_revenue) AS DECIMAL(38,2))                        AS revenue,
    CAST(
        (SIGN(SUM(avg_order_value))
         * FLOOR(ABS(SUM(avg_order_value)) * 100 / COUNT(avg_order_value)))
        / 100
        AS DECIMAL(38,2))                                               AS aov
FROM migration_demo.mart.customer_ltv
GROUP BY region
ORDER BY revenue DESC
