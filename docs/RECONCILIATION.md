# Reconciliation: converted marts and reports vs live Redshift

Run on SQL warehouse `565cd2fd713738c4` against live Redshift (`demo-wg` / `demo`) through the
foreign catalog `redshift_src`, after building `migration_demo.mart.daily_revenue` and
`migration_demo.mart.customer_ltv` with `databricks/etl/10` and `11`.
Run time: 2026-10-27 21:27 UTC. Result: **GREEN on the first run**, no remediation needed.

| Check | Source | Result |
|---|---|---|
| Row counts, 5 tables | `recon/01_row_counts.sql` | all equal |
| `SUM(order_total)`, `MAX(order_ts)` | `recon/02_aggregates.sql` | equal |
| `customer_ltv.avg_order_value` mismatches | `recon/02_aggregates.sql` | 0 |
| Row-level EXCEPT, both marts, both directions | `recon/03_row_diffs.sql` | 0 / 0 / 0 / 0 |
| Scheduled check | `recon/job/recon_check.sql` | `RECONCILIATION GREEN` |
| `reports/20_region_topline` output | `sql/reports` on Redshift vs `databricks/reports` | identical (4 rows) |
| `reports/21_channel_trend` output | `sql/reports` on Redshift vs `databricks/reports` | identical (60 rows) |

Report outputs were diffed as text after stripping the ` 00:00:00` suffix the Redshift Data API
adds to `DATE` values.

## Semantics pinned in the conversion

Checked against the live Redshift marts before conversion:

- `mart.daily_revenue.avg_order_value` is `DECIMAL(38,4)` and equals the exact quotient
  truncated to 4 places on 2,920 / 2,920 rows (rounded matches only 1,810).
- `mart.customer_ltv.avg_order_value` is `DECIMAL(38,2)` and equals the exact mean truncated to
  2 places on 2,000 / 2,000 rows (rounded matches only 1,041).
- `core.orders.order_status` arrives padded (`'CANCELLED '`), so the literal predicate
  `<> 'CANCELLED  '` would keep 10,190 cancelled orders; the converted SQL compares `rtrim(order_status)`.
- `DATEDIFF(day, …)` counts day boundaries, reproduced as `datediff(date, date)`.
- Warehouse session time zone is `Etc/UTC`, matching Redshift `GETDATE()`.

## Raw output

```
== recon/01_row_counts.sql
tbl	src_rows	tgt_rows
core.customers	2000	2000
core.orders	60767	60767
core.order_items	151803	151803
mart.daily_revenue	2920	2920
mart.customer_ltv	2000	2000

== recon/02_aggregates.sql
metric	src_sum	tgt_sum	src_max_ts	tgt_max_ts
orders.order_total	56022828.05	56022828.05	2026-10-26T23:57:13.000Z	2026-10-26T23:57:13.000Z

avg_mismatch_rows
0

== recon/03_row_diffs.sql
side	rows_
daily_revenue src-only	0
daily_revenue tgt-only	0
customer_ltv src-only	0
customer_ltv tgt-only	0

== recon/job/recon_check.sql
recon_result
RECONCILIATION GREEN: all row counts and aggregates match

20_region_topline: IDENTICAL (4 rows)
21_channel_trend: IDENTICAL (60 rows)
```
