# Incident: 2026-08-13 nightly reconciliation failure — freshness drift in core.orders

**Job:** `redshift-migration-nightly-recon` (job_id 220238957207364), failed run_id 663182323398262
**Verdict:** Data catch-up only. No conversion bug; no repo SQL changed.

## Failure (from recon_check task output)

```
RECONCILIATION FAILED:
ROW COUNT MISMATCH core.orders: redshift=61997 databricks=61597;
AGGREGATE MISMATCH orders revenue/max_ts:
  redshift=56334470.17|2026-08-13 00:07:39
  databricks=56231251.54|2026-08-12 18:56:12
```

## Root cause

Freshness drift during the parallel-run period: 400 new rows were inserted
into live Redshift `core.orders` after the last Databricks sync
(Databricks `MAX(order_ts)` = 2026-08-12 18:56:12). New source rows were
observed in every hour from 18:00 UTC through 00:00 UTC on 2026-08-13:

```
hour                      new_orders
2026-08-12 18:00          36
2026-08-12 19:00          10
2026-08-12 20:00          20
2026-08-12 21:00          21
2026-08-12 22:00          14
2026-08-12 23:00          10
2026-08-13 00:00           2
```

Only `core.orders` drifted (customers/order_items counts matched); the
marts on both sides still matched each other because both were built from
pre-drift data. This is stale data, not a translation defect.

## Remediation (data catch-up)

1. Resynced the target: `CREATE OR REPLACE TABLE migration_demo.core.orders
   AS SELECT * FROM redshift_src.core.orders` (Lakehouse Federation).
2. Rebuilt Redshift marts as `demoadmin` from the unchanged legacy ETL
   (`sql/etl/10_build_daily_revenue.sql`, `sql/etl/11_build_customer_ltv.sql`)
   and re-granted `SELECT ON ALL TABLES IN SCHEMA mart TO PUBLIC`.
3. Rebuilt Databricks marts from the converted ETL
   (`databricks/etl/10`, `databricks/etl/11`).
4. Legacy source SQL under `sql/` was not modified.

## Verification (after)

Recon suite (`recon/01–03` from demo-ops) on warehouse 565cd2fd713738c4:

| check | result |
|---|---|
| core.customers rows | 2000 = 2000 |
| core.orders rows | 61997 = 61997 |
| core.order_items rows | 151803 = 151803 |
| mart.daily_revenue rows | 2936 = 2936 |
| mart.customer_ltv rows | 2000 = 2000 |
| SUM(order_total) | 56334470.17 = 56334470.17 |
| MAX(order_ts) | 2026-08-13 00:07:39 = same |
| avg_mismatch_rows | 0 |
| mart EXCEPT diffs (4 directions) | all 0 |

Re-triggered the recon job via Jobs API `run-now`:
run_id 430143287490178 → `recon_check` **SUCCESS** (notify_devin excluded).

## Note

The converted ETL/report files (`databricks/etl`, `databricks/reports`)
are not present on `migration-run-3`; the converted assets used for the
mart rebuild were taken from `migration-run-1` (merged PR #8), matching
the objects already deployed in Unity Catalog `migration_demo`.
