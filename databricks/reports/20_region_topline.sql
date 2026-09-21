SELECT
    region,
    COUNT(*) AS customers,
    SUM(lifetime_revenue) AS revenue,
    AVG(avg_order_value) AS aov,
    SUM(SIZE(tags)) AS tag_count
FROM trino_migration_demo.mart.customer_ltv
GROUP BY region
ORDER BY revenue DESC;
