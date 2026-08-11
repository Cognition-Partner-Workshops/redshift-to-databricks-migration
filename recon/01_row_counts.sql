-- Row-count parity: every row must be accounted for.
SELECT 'core.customers' AS tbl,
       (SELECT COUNT(*) FROM redshift_src.core.customers)   AS src_rows,
       (SELECT COUNT(*) FROM migration_demo.core.customers) AS tgt_rows
UNION ALL
SELECT 'core.orders',
       (SELECT COUNT(*) FROM redshift_src.core.orders),
       (SELECT COUNT(*) FROM migration_demo.core.orders)
UNION ALL
SELECT 'core.order_items',
       (SELECT COUNT(*) FROM redshift_src.core.order_items),
       (SELECT COUNT(*) FROM migration_demo.core.order_items)
UNION ALL
SELECT 'mart.daily_revenue',
       (SELECT COUNT(*) FROM redshift_src.mart.daily_revenue),
       (SELECT COUNT(*) FROM migration_demo.mart.daily_revenue)
UNION ALL
SELECT 'mart.customer_ltv',
       (SELECT COUNT(*) FROM redshift_src.mart.customer_ltv),
       (SELECT COUNT(*) FROM migration_demo.mart.customer_ltv);
