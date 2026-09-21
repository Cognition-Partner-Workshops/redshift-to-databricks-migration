SELECT
    region,
    COUNT(*) AS customers,
    SUM(lifetime_revenue) AS revenue,
    AVG(avg_order_value) AS aov,
    SUM(cardinality(tags)) AS tag_count
FROM lake.mart.customer_ltv
GROUP BY region
ORDER BY revenue DESC;
