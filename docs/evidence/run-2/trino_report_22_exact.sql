WITH promo_orders AS (
    SELECT
        element_at(attrs, 'promo') AS promo,
        order_total
    FROM lake.core.orders
    WHERE element_at(attrs, 'promo') IS NOT NULL
),
grouped AS (
    SELECT
        promo,
        COUNT(*) AS orders,
        array_sort(array_agg(order_total)) AS sorted_totals,
        AVG(order_total) AS average_order_total
    FROM promo_orders
    GROUP BY promo
)
SELECT
    promo,
    orders,
    CAST(
        CASE
            WHEN orders % 2 = 1 THEN element_at(sorted_totals, (orders + 1) / 2)
            ELSE (
                element_at(sorted_totals, orders / 2)
                + element_at(sorted_totals, (orders / 2) + 1)
            ) / 2
        END AS DOUBLE
    ) AS median_order_total,
    CAST(average_order_total AS DECIMAL(12, 2)) AS average_order_total
FROM grouped
ORDER BY median_order_total DESC NULLS LAST, promo NULLS LAST;
