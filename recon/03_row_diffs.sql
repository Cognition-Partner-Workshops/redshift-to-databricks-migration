-- Row-level diffs for the marts. Zero rows = parity.
SELECT 'daily_revenue src-only' AS side, COUNT(*) AS rows_
FROM (
    SELECT * FROM redshift_src.mart.daily_revenue
    EXCEPT
    SELECT * FROM migration_demo.mart.daily_revenue
)
UNION ALL
SELECT 'daily_revenue tgt-only', COUNT(*)
FROM (
    SELECT * FROM migration_demo.mart.daily_revenue
    EXCEPT
    SELECT * FROM redshift_src.mart.daily_revenue
)
UNION ALL
SELECT 'customer_ltv src-only', COUNT(*)
FROM (
    SELECT * FROM redshift_src.mart.customer_ltv
    EXCEPT
    SELECT * FROM migration_demo.mart.customer_ltv
)
UNION ALL
SELECT 'customer_ltv tgt-only', COUNT(*)
FROM (
    SELECT * FROM migration_demo.mart.customer_ltv
    EXCEPT
    SELECT * FROM redshift_src.mart.customer_ltv
);
