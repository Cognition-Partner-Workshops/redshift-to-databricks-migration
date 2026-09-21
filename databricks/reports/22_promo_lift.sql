-- Converted from trino/sql/reports/22_promo_lift.sql
--   CROSS JOIN UNNEST(map_entries(attrs)) AS u(k, v) -> LATERAL VIEW explode(attrs)
--   approx_percentile(x, 0.5)                        -> percentile_approx(x, 0.5)
-- Trino's approx_percentile is non-deterministic: the same query over unchanged data
-- returns a different median between runs (see docs/evidence/run-4). Databricks'
-- percentile_approx is deterministic, so this column cannot be reconciled to an exact
-- value against a single Trino run - see the open item in the PR. exact_median is
-- carried alongside so the report has a stable number to compare on.
SELECT
    attr_value                                    AS promo,
    COUNT(*)                                      AS orders,
    percentile_approx(order_total, 0.5)           AS median_order_total,
    CAST(percentile(order_total, 0.5) AS DECIMAL(12, 2)) AS exact_median,
    CAST(AVG(order_total) AS DECIMAL(12, 2))      AS average_order_total
FROM trino_migration_demo_run4.core.orders o
LATERAL VIEW explode(o.attrs) u AS attr_key, attr_value
WHERE attr_key = 'promo'
GROUP BY attr_value
ORDER BY median_order_total DESC
