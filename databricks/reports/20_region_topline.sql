-- cardinality() exists in Databricks SQL. AVG over DECIMAL(12,2) is DECIMAL(12,2) in Trino but widens to
-- DECIMAL(16,6) in Databricks; cast back so aov keeps the same scale as the Trino report.
SELECT
    region,
    COUNT(*) AS customers,
    SUM(lifetime_revenue) AS revenue,
    CAST(AVG(avg_order_value) AS DECIMAL(12, 2)) AS aov,
    SUM(cardinality(tags)) AS tag_count
FROM trino_migration_demo.mart.customer_ltv
GROUP BY region
ORDER BY revenue DESC;
