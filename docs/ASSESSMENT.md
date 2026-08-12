# Redshift → Databricks Migration Assessment

Source: Amazon Redshift Serverless (workgroup `demo-wg`, database `demo`, us-east-1).
Target: Databricks Unity Catalog (`migration_demo`), landed via Lakehouse Federation (foreign catalog `redshift_src`).

## Risk Summary

| # | Asset | Type | Redshift-specific features | Risk | Notes |
|---|-------|------|-----------------------------|------|-------|
| 1 | `sql/etl/12_sp_refresh_marts.sql` | Stored procedure | plpgsql procedure, `RAISE INFO`, `GETDATE()` | **High** | No plpgsql in Databricks; replace with a Workflow/job orchestrating the mart builds |
| 2 | `sql/etl/10_build_daily_revenue.sql` | ETL (mart build) | `DECODE`, `TRUNC(timestamp)`, `GETDATE()`, CHAR blank-padded comparison, `DISTSTYLE ALL`/`SORTKEY`, DECIMAL division | **High** | Multiple dialect rewrites; blank-padded `'CANCELLED  '` filter silently breaks on trimmed strings |
| 3 | `sql/etl/11_build_customer_ltv.sql` | ETL (mart build) | `DATEDIFF(day, ts, ts)`, CHAR blank-padded comparison, `AVG(DECIMAL)` semantics, `DISTKEY`/`SORTKEY` | **High** | Redshift `AVG(DECIMAL)` truncates to the source scale; Spark rounds at a wider scale — flagged as a reconciliation divergence, not silently patched |
| 4 | `sql/ddl/02_core_tables.sql` | DDL | `IDENTITY(1,1)`, `CHAR(n)` blank padding, `GETDATE()` defaults, `DISTSTYLE`/`DISTKEY`/`SORTKEY`, `SMALLINT` | **Medium** | IDENTITY → `GENERATED ALWAYS AS IDENTITY`; CHAR → STRING (padding behavior changes); dist/sort keys → drop or map to liquid clustering |
| 5 | `sql/reports/21_channel_trend.sql` | BI report | `DATEADD`, `TRUNC(GETDATE())` | **Medium** | `DATEADD(day, -30, ...)` → `date_add`/`dateadd`; `TRUNC(GETDATE())` → `current_date()` |
| 6 | `sql/reports/20_region_topline.sql` | BI report | `AVG(DECIMAL)` semantics only | **Low** | Portable aggregate SQL; only decimal AVG scale differs |
| 7 | `sql/ddl/01_schemas.sql` | DDL | none | **Low** | Direct `CREATE SCHEMA` mapping under UC catalog |

## Feature-by-feature conversion notes

### DISTKEY / SORTKEY / DISTSTYLE
Physical-layout hints with no direct Databricks equivalent. Delta Lake handles layout via clustering; drop these clauses and, where join/pruning performance matters (`core.orders`, `mart.daily_revenue`), consider `CLUSTER BY` (liquid clustering) on the former sort keys.

### CHAR(n) blank padding
Redshift `CHAR` pads values with trailing spaces, and the ETL depends on it: `order_status <> 'CANCELLED  '` compares against a 10-char padded literal. Databricks `STRING` does not pad. Conversion must either trim consistently (`order_status <> 'CANCELLED'` with `TRIM`) or keep CHAR semantics deliberately. Affects `customer_code`, `region`, `order_status`, `sku`.

### IDENTITY columns
`IDENTITY(1,1)` on all three core tables. Backfill via CTAS preserves existing values; future inserts need `GENERATED ALWAYS AS IDENTITY` (Delta) — sequence values will not match Redshift's (Redshift IDENTITY is not gap-free either).

### GETDATE()
Not available in Spark SQL. Map to `current_timestamp()`; `TRUNC(GETDATE())` → `current_date()`. Appears in DDL defaults, both ETL builds, the stored procedure, and one report.

### DECODE
Redshift `DECODE(expr, s1, r1, s2, r2, default)` → `CASE WHEN`. Used in the daily-revenue channel grouping.

### TRUNC(timestamp)
Redshift `TRUNC(ts)` returns a DATE. Spark `trunc()` operates on dates with a format argument — use `CAST(ts AS DATE)` or `date_trunc('DAY', ts)` (note: `date_trunc` returns TIMESTAMP, not DATE).

### DECIMAL arithmetic and AVG semantics
- Redshift `AVG(DECIMAL(12,2))` returns DECIMAL(12,2), truncating extra precision. Spark widens (`DECIMAL(16,6)`) and rounds. Observed on live data: `AVG(order_total)` over `core.orders` returns `921.58` in Redshift vs `921.589023` in Databricks — identical underlying data (SUM and COUNT match exactly), but Redshift truncates to scale 2 while Spark keeps a wider scale that rounds to `921.59`. Reconciliation of `avg_order_value` must compare at an agreed scale; this is a semantics divergence to surface, not silently normalize.
- `SUM(order_total) / NULLIF(COUNT(...),0)` division result type/scale also differs between engines.

### DATEDIFF
Redshift `DATEDIFF(day, a, b)` counts day-boundary crossings. Databricks `datediff(end, start)` takes dates in the opposite argument order and no unit; `timestampdiff(DAY, a, b)` counts full 24h periods. Boundary-crossing vs elapsed-period semantics can differ by 1 for the `active_days` measure.

### Stored procedure (`mart.sp_refresh_marts`)
plpgsql wrapper invoked by the customer's scheduler. Databricks SQL has no plpgsql; replace with a Databricks Workflow (or DLT pipeline) running the converted mart builds in order, with logging via job runs instead of `RAISE INFO`.

## Migration plan (this phase)
1. Land `core.customers`, `core.orders`, `core.order_items` into `migration_demo.core` as Delta tables via CTAS from the federated catalog `redshift_src`.
2. Verify exactness against live Redshift: row counts, SUM/AVG of `order_total` to the cent, min/max timestamps per table.
3. Subsequent phase: convert ETL/report SQL per the notes above and rebuild `migration_demo.mart`, reconciling against Redshift marts.
