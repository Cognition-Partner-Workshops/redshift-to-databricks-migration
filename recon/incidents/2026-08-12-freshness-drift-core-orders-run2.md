# Incident: reconciliation failure — freshness drift in core.orders (run 2)

- **Date:** 2026-08-12
- **Trigger:** Scheduled Databricks recon job 220238957207364, run 83886079157947
  (task `recon_check`) failed with:
  `RECONCILIATION FAILED: ROW COUNT MISMATCH core.orders: redshift=61197 databricks=60797;
  AGGREGATE MISMATCH orders revenue/max_ts: redshift=56129694.60|2026-08-12 18:51:26
  databricks=56029847.86|2026-08-12 14:22:24`

## Root cause

Freshness drift, not a conversion logic bug. 400 new orders
(order_ts 2026-08-11 18:59:26 → 2026-08-12 18:51:26, order_total sum 99,846.74)
landed in Redshift `core.orders` after the last sync; `migration_demo.core.orders`
lacked them. No drift in `core.order_items` (151,803 = 151,803, and the 400 new
orders have no item rows) or `core.customers` (2,000 = 2,000). The converted ETL
SQL was verified unchanged and correct — rebuilding the marts from synced core
data restored full parity, confirming a pure data-freshness issue.

## Remediation (data catch-up only — no SQL changes)

1. Incremental sync on the Databricks warehouse (565cd2fd713738c4) via federation:
   `INSERT INTO migration_demo.core.orders SELECT ... FROM redshift_src.core.orders s
   WHERE NOT EXISTS (SELECT 1 FROM migration_demo.core.orders t
   WHERE t.order_id = s.order_id)` — 400 rows inserted. `core.order_items` and
   `core.customers` required no sync (0 missing rows).
2. Rebuilt the Databricks marts with the converted ETL
   (`databricks/etl/10_build_daily_revenue.sql`, `databricks/etl/11_build_customer_ltv.sql`).
3. Refreshed the Redshift marts with the legacy nightly ETL
   (`sql/etl/10_build_daily_revenue.sql`, `sql/etl/11_build_customer_ltv.sql`) so both
   estates reflect the same snapshot during the parallel-run period.

## Evidence

Before (from the failed job run and manual recon re-run):

| object | redshift | databricks |
|---|---|---|
| core.orders rows | 61197 | 60797 |
| orders SUM(order_total) | 56129694.60 | 56029847.86 |
| orders MAX(order_ts) | 2026-08-12 18:51:26 | 2026-08-12 14:22:24 |

After (recon suite re-run at ~19:20 UTC on warehouse 565cd2fd713738c4):

- Row counts: core.customers 2000 = 2000; core.orders 61197 = 61197;
  core.order_items 151803 = 151803; mart.daily_revenue 2928 = 2928;
  mart.customer_ltv 2000 = 2000 — all match
- Aggregates: orders SUM(order_total) 56,129,694.60 = 56,129,694.60;
  MAX(order_ts) 2026-08-12 18:51:26 on both; customer_ltv avg_order_value
  mismatches: 0 rows
- Row-level EXCEPT diffs: 0 rows in all four directions (both marts)
- `recon_check.sql`: `RECONCILIATION GREEN: all row counts and aggregates match`

Re-triggered the scheduled recon job (Jobs API run-now): run 637145460571200 — `TERMINATED SUCCESS`.
