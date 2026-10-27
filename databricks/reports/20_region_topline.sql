-- BI report: region topline (consumed by the exec dashboard)
-- Converted from sql/reports/20_region_topline.sql.
--   AVG(DECIMAL(38,2)) -> Redshift keeps scale 2 and truncates; reproduced with integer division on cents
SELECT
    region,
    COUNT(*)                    AS customers,
    SUM(lifetime_revenue)       AS revenue,
    CAST(
        CAST(CAST(SUM(avg_order_value) * 100 AS BIGINT) DIV COUNT(avg_order_value)
             AS DECIMAL(38,2)) / 100
        AS DECIMAL(38,2))       AS aov
FROM migration_demo.mart.customer_ltv
GROUP BY region
ORDER BY revenue DESC;
