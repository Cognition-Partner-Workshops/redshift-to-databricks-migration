# Redshift → Databricks Migration Assessment

Scope: every SQL asset under `sql/` (2 DDL, 3 ETL, 2 report files; 5 tables, 1 procedure, 2 report queries). Target: Unity Catalog `migration_demo` (`core`, `mart` schemas) on warehouse `565cd2fd713738c4`, with `redshift_src` (Lakehouse Federation) as the live read-only view of Redshift during coexistence.

## Risk summary

Ranked by how hard the asset is to migrate *faithfully* (same numbers out, not just "it parses").

| Rank | Asset | Risk | Why it is hard | Migration approach |
|---|---|---|---|---|
| 1 | `sql/etl/10_build_daily_revenue.sql` | **High** | `TRUNC(timestamp)` → date, `DECODE`, `GETDATE()`, blank-padded `CHAR(10)` literal `'CANCELLED  '` in a filter, `SUM/NULLIF(COUNT DISTINCT)` decimal division (result scale differs by engine), `DISTSTYLE ALL`/`SORTKEY` | Rewrite as `CREATE OR REPLACE TABLE ... AS` with `CAST(order_ts AS DATE)`, `CASE`, `current_date()`, `TRIM(order_status) <> 'CANCELLED'`, explicit `CAST(... AS DECIMAL(18,2))` on the AOV; drop dist/sort keys, consider liquid clustering on `order_date` |
| 2 | `sql/etl/11_build_customer_ltv.sql` | **High** | `AVG(DECIMAL)` result scale (Redshift keeps scale 2 and truncates; Databricks widens to scale 6 — confirmed live: 896.19 vs 896.1963 on `core.orders`), `DATEDIFF(day, a, b)` argument order/semantics, same `CHAR` padding filter, `DISTKEY/SORTKEY` | Pin `avg_order_value` to an explicit `DECIMAL(18,2)` with an agreed rounding rule; convert to `datediff(DAY, a, b)` and verify day-boundary behaviour; strip dist/sort keys |
| 3 | `sql/etl/12_sp_refresh_marts.sql` | **High** | PL/pgSQL stored procedure (`RAISE INFO`, `$$` body); the actual build steps are invoked by an external scheduler in numeric order (10, 11), so dependencies are implicit. References `mart.daily_revenue_stage`, a table nothing else in the repo creates | No 1:1 procedure target. Replace with a Databricks Job (two SQL tasks, 10 → 11, plus a recon task) or SQL scripting; the stage-table drop is dead code and should be confirmed with the owner before being dropped |
| 4 | `sql/ddl/02_core_tables.sql` | **Medium** | `IDENTITY(1,1)` (gap semantics differ from `GENERATED ALWAYS AS IDENTITY`), `CHAR(n)` blank padding (Databricks has no padded CHAR storage; comparisons on `region`, `order_status`, `sku`, `customer_code` must be normalised), `SMALLINT`, `DECIMAL(5,4)`, `DEFAULT GETDATE()`, `DISTSTYLE/DISTKEY/SORTKEY` | Landed like-for-like via federation CTAS (`CHAR`→`STRING`, `DECIMAL` precision preserved, `TIMESTAMP` timezone-naive). Identity columns are not re-declared; downstream inserts must not rely on Redshift-style identity generation |
| 5 | `sql/reports/21_channel_trend.sql` | **Medium** | `DATEADD(day, -30, TRUNC(GETDATE()))` and `order_date` type: Redshift `TRUNC()` yields a timestamp-shaped date in results, Databricks yields `DATE`. 30-day window is relative to run time, so parity tests must fix the "as of" date | `date_sub(current_date(), 30)`; run parity with a pinned `as_of` parameter |
| 6 | `sql/reports/20_region_topline.sql` | **Low–Medium** | `AVG(avg_order_value)` compounds the decimal-scale issue from rank 2; `ORDER BY revenue DESC` ties are non-deterministic across engines | Round to agreed scale before comparing; add `region` as a secondary sort key |
| 7 | `sql/ddl/01_schemas.sql` | **Low** | `CREATE SCHEMA IF NOT EXISTS` is identical | Created as `migration_demo.core` and `migration_demo.mart` |

Cross-cutting: all three `mart` builders use Drop + CTAS full refresh — trivially idempotent on Databricks (`CREATE OR REPLACE TABLE`) but any consumer reading mid-refresh sees an empty/absent table on Redshift and a consistent snapshot on Delta; this is an improvement, not a parity break, but should be noted for the BI team.

## Inventory

| File | Type | Objects | Reads | Writes |
|---|---|---|---|---|
| `sql/ddl/01_schemas.sql` | DDL | schemas `core`, `mart` | — | — |
| `sql/ddl/02_core_tables.sql` | DDL | `core.customers`, `core.orders`, `core.order_items` | — | — |
| `sql/etl/10_build_daily_revenue.sql` | ETL (Drop+CTAS) | `mart.daily_revenue` | `core.orders`, `core.customers` | `mart.daily_revenue` |
| `sql/etl/11_build_customer_ltv.sql` | ETL (Drop+CTAS) | `mart.customer_ltv` | `core.customers`, `core.orders` | `mart.customer_ltv` |
| `sql/etl/12_sp_refresh_marts.sql` | Procedure | `mart.sp_refresh_marts()` | — | drops `mart.daily_revenue_stage` (inferred dead) |
| `sql/reports/20_region_topline.sql` | Report | — | `mart.customer_ltv` | — |
| `sql/reports/21_channel_trend.sql` | Report | — | `mart.daily_revenue` | — |

`core.order_items` is landed but not consumed by any ETL or report in the repo; it is in scope for backfill (source of truth for line-level revenue) and flagged for a hidden-consumer sweep of Redshift query history before cutover.

## Dialect findings (confirmed against live systems)

| Redshift | Databricks SQL | Note |
|---|---|---|
| `AVG(DECIMAL(12,2))` → `DECIMAL(?,2)`, truncated | `DECIMAL(?,6)` | Live: 896.19 vs 896.1963. Use `SUM/COUNT` with explicit `CAST` in both ETL and recon |
| `CHAR(n)` blank-padded; `'CANCELLED  '` literal | `STRING`, no padding | Filter on `TRIM(order_status)`; recon compares trimmed values |
| `TRUNC(ts)` | `CAST(ts AS DATE)` / `date_trunc` | Data API renders Redshift dates as `YYYY-MM-DD 00:00:00` |
| `GETDATE()` | `current_timestamp()` / `current_date()` | |
| `DECODE(x, a, b, c, d, default)` | `CASE WHEN` | |
| `DATEADD(day, n, d)` / `DATEDIFF(day, a, b)` | `date_add`/`date_sub`, `datediff(DAY, a, b)` | Argument order is compatible for `datediff` with unit; verify |
| `DISTSTYLE`/`DISTKEY`/`SORTKEY` | none (liquid clustering optional) | Do not carry as comments |
| `IDENTITY(1,1)` | `GENERATED ALWAYS AS IDENTITY` | Values copied verbatim on backfill; not re-declared |
| PL/pgSQL procedure | Databricks Job / SQL scripting | Orchestration, not SQL, is the real migration |

## Backfill plan (executed this session)

| Table | Class | Method | Rows | Verification |
|---|---|---|---|---|
| `core.customers` | small, static | federation CTAS, single shot | 2,000 | counts, distinct keys, nulls, date bounds |
| `core.orders` | small, append-only | federation CTAS, single shot (watermark: `MAX(loaded_at)` recorded in recon) | 63,197 | counts, distinct keys, SUM/AVG to the cent, status counts, ts bounds |
| `core.order_items` | small, append-only | federation CTAS, single shot | 151,803 | counts, distinct keys, SUM qty/gross/discount, key bounds |

`databricks/backfill/01_core_backfill.sql` creates the schemas and the three Delta tables; `scripts/verify_backfill.py` is the recon (one aggregate statement per table per side, exits nonzero on any mismatch). `core.orders` is append-only and receives new rows continuously, so the Delta copy is a point-in-time snapshot; a resync (re-run the CTAS) or an incremental load keyed on `loaded_at` is required before mart parity testing.

## Next steps

1. Convert `10`, `11` to Databricks SQL under `databricks/etl/` applying the dialect findings above; build `migration_demo.mart`.
2. Replace `sp_refresh_marts` with a scheduled Databricks Job (10 → 11 → recon).
3. Report parity for `20`, `21` against Redshift with pinned `as_of` date and agreed rounding.
4. Governance: sweep Redshift grants on `core`/`mart` and map to UC grants before any consumer repoint.
