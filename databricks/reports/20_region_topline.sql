SELECT
    region,
    COUNT(*) AS customers,
    SUM(lifetime_revenue) AS revenue,
    CAST(AVG(avg_order_value) AS DECIMAL(12, 2)) AS aov,
    SUM(size(tags)) AS tag_count
FROM trino_migration_demo.mart.customer_ltv
GROUP BY region
ORDER BY revenue DESC;
