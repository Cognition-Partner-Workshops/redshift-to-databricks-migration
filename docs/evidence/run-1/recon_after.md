object	trino_rows	dbx_rows
core.orders	5000	5000
core.order_items	12000	12000
ops.customers	200	200
ops.customer_tags	401	401
mart.daily_revenue	360	360
mart.customer_ltv	150	150
---
mart	side	rows_	sum_orders	sum_gross	sum_aov	min_date	max_date
customer_ltv	databricks	150	3750	1312662.50	52506.50	2026-05-24T00:00:00.000Z	2026-09-21T00:00:00.000Z
customer_ltv	trino	150	3750	1312662.50	52506.50	2026-05-24T00:00:00.000Z	2026-09-21T00:00:00.000Z
daily_revenue	databricks	360	3716	1301438.76	126565.89	2026-05-24T00:00:00.000Z	2026-09-20T00:00:00.000Z
daily_revenue	trino	360	3716	1301438.76	126565.89	2026-05-24T00:00:00.000Z	2026-09-20T00:00:00.000Z
---
diff	rows_
daily_revenue trino-minus-dbx	0
daily_revenue dbx-minus-trino	0
daily_revenue aov mismatch (raw, unrounded)	0
customer_ltv trino-minus-dbx	0
customer_ltv dbx-minus-trino	0
customer_ltv aov mismatch (raw, unrounded)	0
---
