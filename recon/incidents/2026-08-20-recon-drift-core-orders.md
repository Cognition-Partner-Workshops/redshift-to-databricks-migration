# Incident: nightly recon failure — core.orders drift (2026-08-20)

## Event
Databricks job `redshift-migration-nightly-recon` (job 220238957207364, run 677594760623315,
recon task run 222595624146254) failed at 2026-08-20 ~04:41 UTC:

```
RECONCILIATION FAILED: ROW COUNT MISMATCH core.orders: redshift=62797 databricks=62397;
AGGREGATE MISMATCH orders revenue/max_ts:
  redshift=56534492.12|2026-08-20 04:39:27  databricks=56435261.21|2026-08-13 00:24:07
```

## Root cause
Fresh source-side data, not a conversion bug. 400 new rows were inserted into live
Redshift `core.orders` shortly before the run (orders-only insert; `core.customers`
and `core.order_items` were unchanged, and all mart row counts still matched because
neither side's marts had been rebuilt). The migrated copy
`migration_demo.core.orders` was stale at the 2026-08-13 snapshot (62,397 rows,
max order_ts 2026-08-13 00:24:07) while Redshift had advanced to 62,797 rows /
max order_ts 2026-08-20 04:39:27 (+$99,230.91 revenue). Verified by re-running
`recon/01–03` (branch demo-ops) on warehouse 565cd2fd713738c4 against the
`redshift_src` federation catalog.

## Remediation (pure data catch-up — no code changes)
1. Resynced target: `CREATE OR REPLACE TABLE migration_demo.core.orders AS SELECT * FROM redshift_src.core.orders`.
2. Rebuilt Redshift marts as demoadmin via the unchanged legacy ETL
   (`sql/etl/10`, `sql/etl/11`) and re-granted `SELECT ON ALL TABLES IN SCHEMA mart TO PUBLIC`.
3. Rebuilt Databricks marts with the converted ETL (`databricks/etl/10`, `databricks/etl/11`
   from the open conversion PR branch).

## After (all green)

| check | redshift | databricks |
|---|---|---|
| core.customers rows | 2000 | 2000 |
| core.orders rows | 62797 | 62797 |
| core.order_items rows | 151803 | 151803 |
| mart.daily_revenue rows | 2949 | 2949 |
| mart.customer_ltv rows | 2000 | 2000 |
| SUM(order_total) | 56534492.12 | 56534492.12 |
| MAX(order_ts) | 2026-08-20 04:39:27 | 2026-08-20 04:39:27 |
| avg_order_value mismatch rows | 0 | — |
| mart EXCEPT diffs (4 directions) | 0 | 0 |

## Re-verification
Re-triggered the recon job via Jobs API Run Now: run 137365731020146 →
`TERMINATED / SUCCESS` at ~05:00 UTC 2026-08-20.
