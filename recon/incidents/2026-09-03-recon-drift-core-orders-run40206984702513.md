# Incident: nightly recon failure — core.orders drift (job run 40206984702513)

- **Date:** 2026-09-03 (job started 04:51:22 UTC; `notify_devin` fired the recon-failure webhook)
- **Job:** `redshift-migration-nightly-recon` (id 220238957207364), run 40206984702513
- **Failing task:** `recon_check` (task run 160138989121100) — `raise_error`:
  `RECONCILIATION FAILED: AGGREGATE MISMATCH orders revenue/max_ts: redshift=56839114.64|2026-09-03 04:33:35 databricks=56734168.36|2026-09-02 04:58:49; ROW COUNT MISMATCH core.orders: redshift=63997 databricks=63597`

## Root cause

Source-side freshness drift, not a conversion bug. A single batch of 400 orders
(`order_id` 63598–63997, all `loaded_at` = 2026-09-03 04:35:36 UTC, `order_ts` back-dated
across 2026-09-02 04:37:35 → 2026-09-03 04:33:35, all status `PLACED`) landed in live Redshift
`core.orders` about 16 minutes before the recon job started. `migration_demo.core.orders` had
been backfilled by the run-8 migration session at 04:24:41 UTC (63597 rows, `DESCRIBE HISTORY`
version 0) — 11 minutes *before* the batch — so the target was a point-in-time copy that the
source had since moved past.

Evidence (queried on warehouse 565cd2fd713738c4 through `redshift_src`, and cross-checked
directly on Redshift via the Data API):

- `LEFT ANTI JOIN` on `order_id`: exactly **400** rows in Redshift and missing in Databricks;
  **0** rows in Databricks and missing in Redshift.
- Sum of the 400 missing rows' `order_total` = **104946.28** = 56839114.64 − 56734168.36 (the
  aggregate gap is fully explained by the missing rows); their `MAX(order_ts)` = 2026-09-03
  04:33:35 = the source-side max in the failure message.
- **0** common rows differ on any column (`customer_id`, `order_ts`, `order_status`,
  `order_total`, `sales_channel`) — pure appends, no updates/deletes.
- `core.customers` (2000/2000) and `core.order_items` (151803/151803) unaffected; no
  `order_items` exist for the 400 new orders on either side.
- Marts were equal on both sides before remediation (2973/2973 and 2000/2000 rows,
  `avg_mismatch_rows` = 0, all four `EXCEPT` diffs 0; both `mart.daily_revenue` at
  max `order_date` 2026-09-02) because the Redshift nightly mart refresh had not run since the
  batch either. This rules out the converted ETL/report SQL (PR #29) as a cause.

## Remediation (data catch-up only — no code changes)

1. Caught the target up through federation, idempotently (schema preserved, only missing keys):
   `INSERT INTO migration_demo.core.orders SELECT s.* FROM redshift_src.core.orders s LEFT ANTI JOIN migration_demo.core.orders t ON s.order_id = t.order_id`
   → `num_inserted_rows = 400`.
2. Refreshed Redshift marts as `demoadmin` by running the customer's unchanged nightly ETL
   (`sql/etl/10_build_daily_revenue.sql`, `sql/etl/11_build_customer_ltv.sql`), then
   `GRANT SELECT ON ALL TABLES IN SCHEMA mart TO PUBLIC` (DROP + CTAS loses grants; the
   federation user needs SELECT). Nothing under `sql/` was modified; `core.*` was not touched.
3. Rebuilt Databricks marts with the converted ETL from PR #29
   (`databricks/etl/10_build_daily_revenue.sql`, `databricks/etl/11_build_customer_ltv.sql`), unchanged.

Mart row counts did not change (2973 / 2000): the new orders fall on dates already present in
`daily_revenue` (2026-09-03 rows are excluded by `order_ts < current_date`) and belong to
existing customers, so only the aggregate values moved — identically on both sides.

## Evidence — before vs after

| Check | Before | After |
|---|---|---|
| core.orders rows (src/tgt) | 63997 / 63597 | 63997 / 63997 |
| SUM(order_total) (src/tgt) | 56839114.64 / 56734168.36 | 56839114.64 / 56839114.64 |
| MAX(order_ts) (src/tgt) | 2026-09-03 04:33:35 / 2026-09-02 04:58:49 | 2026-09-03 04:33:35 / 2026-09-03 04:33:35 |
| core.customers rows (src/tgt) | 2000 / 2000 | 2000 / 2000 |
| core.order_items rows (src/tgt) | 151803 / 151803 | 151803 / 151803 |
| mart.daily_revenue rows (src/tgt) | 2973 / 2973 (both stale) | 2973 / 2973 (both refreshed) |
| mart.customer_ltv rows (src/tgt) | 2000 / 2000 | 2000 / 2000 |
| orders anti-join (src-only / tgt-only) | 400 / 0 | 0 / 0 |
| avg_mismatch_rows (customer_ltv) | 0 | 0 |
| mart EXCEPT diffs (4 checks) | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 |
| `recon/job/recon_check.sql` | RECONCILIATION FAILED (above) | RECONCILIATION GREEN: all row counts and aggregates match |

## Verification

Full recon suite (`recon/01`–`03` from demo-ops) and the job's `recon_check.sql` green on
warehouse 565cd2fd713738c4, then re-triggered the recon job via Jobs API Run Now:
run **259427018209890** terminated `SUCCESS` — `recon_check` passed, `notify_devin` excluded
(`All upstream tasks succeeded`).

## Follow-up

The target is a point-in-time copy; every source append will re-trigger this incident until a
scheduled catch-up (the anti-join insert above, or a `MERGE` on `order_id`) runs before the
recon, or the recon is re-scoped to a cutoff. The converted `mart-refresh-nightly` job
(`databricks/jobs/refresh_marts.job.yml`, PR #29) is not yet deployed to the workspace; when it
is, it should be preceded by the same core-table catch-up so both sides refresh from the same
source snapshot. This is a decision for the migration owners, not made here.
