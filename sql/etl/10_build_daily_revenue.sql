-- Nightly ETL: rebuild mart.daily_revenue from core.orders.
-- Redshift-isms: GETDATE(), DATEADD, TRUNC(timestamp) -> date, DECODE().

DROP TABLE IF EXISTS mart.daily_revenue;

CREATE TABLE mart.daily_revenue
DISTSTYLE ALL
SORTKEY (order_date)
AS
SELECT
    TRUNC(o.order_ts)                                   AS order_date,
    c.region,
    DECODE(o.sales_channel, 'web', 'ONLINE',
                            'app', 'ONLINE',
                            'RETAIL')                   AS channel_group,
    COUNT(DISTINCT o.order_id)                          AS order_count,
    SUM(o.order_total)                                  AS gross_revenue,
    SUM(o.order_total) / NULLIF(COUNT(DISTINCT o.order_id), 0)
                                                        AS avg_order_value
FROM core.orders o
JOIN core.customers c ON c.customer_id = o.customer_id
WHERE o.order_status <> 'CANCELLED  '                    -- CHAR(10) blank-padded compare
  AND o.order_ts < TRUNC(GETDATE())
GROUP BY 1, 2, 3;
