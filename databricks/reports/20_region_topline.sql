-- Converted from trino/sql/reports/20_region_topline.sql
--   cardinality(tags) -> size(tags)
--   AVG(DECIMAL(12,2)) keeps scale 2 in Trino, so the Databricks result is cast back
SELECT
    region,
    COUNT(*)                                   AS customers,
    CAST(SUM(lifetime_revenue) AS DECIMAL(38, 2)) AS revenue,
    CAST(AVG(avg_order_value) AS DECIMAL(12, 2))  AS aov,
    SUM(size(tags))                            AS tag_count
FROM trino_migration_demo_run4.mart.customer_ltv
GROUP BY region
ORDER BY revenue DESC
