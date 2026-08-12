# Incident: reconciliation failure — freshness drift in core.orders

- **Date:** 2026-08-12
- **Trigger:** Scheduled Databricks recon job 220238957207364, run 468903961859523
  (task `recon_check`) failed with:
  `RECONCILIATION FAILED: ROW COUNT MISMATCH core.orders: redshift=60797 databricks=60772;
  AGGREGATE MISMATCH orders revenue/max_ts: redshift=56029847.86|2026-08-12 14:22:24
  databricks=56023718.53|2026-08-11 23:00:06`

## Root cause

Freshness drift, not a conversion logic bug. 25 new orders (order_id 60773–60797,
order_ts 2026-08-11 16:23:24 → 2026-08-12 14:22:24, order_total sum 6,129.33) landed in
Redshift `core.orders` after the last backfill; `migration_demo.core.orders` lacked them.
No drift in `core.order_items` (151,803 = 151,803) or `core.customers` (2,000 = 2,000).
Mart-level recon (`recon/run_recon.py`) was still green because the Redshift marts had
not been refreshed since the drift either — the mismatch surfaced only at the core layer
checked by the scheduled job.

## Remediation (data catch-up only — no SQL changes)

1. Incremental sync on the Databricks warehouse (565cd2fd713738c4) via federation:
   `INSERT INTO migration_demo.core.orders SELECT * FROM redshift_src.core.orders s
   WHERE s.order_id NOT IN (SELECT order_id FROM migration_demo.core.orders)` — 25 rows.
   Equivalent statement for `core.order_items` inserted 0 rows.
2. Refreshed the Redshift marts with the legacy nightly ETL
   (`sql/etl/10_build_daily_revenue.sql`, `sql/etl/11_build_customer_ltv.sql`) and the
   Databricks marts with the converted ETL (`databricks/etl/12_sp_refresh_marts.sql`),
   so both estates reflect the same snapshot.

## Evidence

Before (core layer, from the failed job run):

| object | redshift | databricks |
|---|---|---|
| core.orders rows | 60797 | 60772 |
| orders SUM(order_total) | 56029847.86 | 56023718.53 |
| orders MAX(order_ts) | 2026-08-12 14:22:24 | 2026-08-11 23:00:06 |

After (recon/run_recon.py at 2026-08-12 15:06 UTC):

- Row counts: daily_revenue 2927 = 2927; customer_ltv 2000 = 2000 — match
- Per-column aggregates (to the cent): match on both marts
  (daily_revenue gross_revenue_sum 46,617,214.19; customer_ltv lifetime_revenue_sum
  46,620,937.03, max last_order_ts 2026-08-12 14:22:24)
- Row-level EXCEPT diffs: 0 rows in all four directions
- Report outputs (legacy on Redshift vs converted on Databricks): identical
  (20_region_topline 4 rows; 21_channel_trend 60 rows)
- `RECONCILIATION GREEN.` (exit 0)

Re-triggered the scheduled recon job (Jobs API run-now): run 326455545363405 —
`TERMINATED SUCCESS`.
