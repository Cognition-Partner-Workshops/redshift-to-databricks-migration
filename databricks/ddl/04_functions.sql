-- Canonical avg_order_value.
--
-- Redshift defined the metric twice with different formulas:
--   mart.daily_revenue : SUM(order_total) / NULLIF(COUNT(DISTINCT order_id), 0)  -> DECIMAL(38,4)
--   mart.customer_ltv  : AVG(order_total)                                        -> DECIMAL(38,2)
-- order_id is unique, so both are "gross revenue of valid orders / number of valid
-- orders" at the grain of the mart. They differ only in published scale, and
-- Redshift DECIMAL arithmetic truncates toward zero at that scale where
-- Databricks would round. This function is the single definition: the ratio,
-- truncated toward zero at the requested scale, NULL when there are no orders.
-- `div` is exact integral division (no intermediate rounding), so the result
-- matches Redshift to the last digit. Every mart and report calls this instead
-- of re-deriving the metric.
CREATE OR REPLACE FUNCTION migration_demo.silver.avg_order_value(
    gross_revenue DECIMAL(38,2) COMMENT 'SUM(order_total) of valid orders in the group',
    order_count   BIGINT        COMMENT 'number of valid orders in the group',
    scale         INT           COMMENT 'decimal places to keep (0..4): 4 for daily_revenue, 2 for customer_ltv'
)
RETURNS DECIMAL(38,4)
COMMENT 'Canonical average order value: gross_revenue / order_count truncated toward zero at `scale` decimals'
RETURN
    CASE
        WHEN order_count IS NULL OR order_count = 0 THEN NULL
        ELSE CAST((gross_revenue * CAST(power(10, scale) AS DECIMAL(38,0))) div order_count
                  AS DECIMAL(38,4))
             / CAST(power(10, scale) AS DECIMAL(38,0))
    END;
