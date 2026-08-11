-- BI report: region topline (consumed by the exec dashboard)
SELECT
    region,
    COUNT(*)                    AS customers,
    SUM(lifetime_revenue)       AS revenue,
    AVG(avg_order_value)        AS aov
FROM mart.customer_ltv
GROUP BY region
ORDER BY revenue DESC;
