# Warehouse Analytics — Redshift

SQL estate for our order-analytics warehouse on Amazon Redshift Serverless
(workgroup `demo-wg`, database `demo`, us-east-1).

## Layout

- `sql/ddl/` — table definitions (core order/customer tables)
- `sql/etl/` — nightly mart builds, run in numeric order by the scheduler
  (`10_*` → `11_*`), plus the `mart.sp_refresh_marts` wrapper procedure
- `sql/reports/` — BI report queries consumed by the exec dashboard

## Conventions

- Marts are rebuilt nightly by full refresh (DROP + CTAS).
- `core.*` tables are append-only; orders land continuously from the
  ingestion pipeline.
- Distribution/sort keys are tuned for the current query mix — see the DDL
  before changing join patterns.
