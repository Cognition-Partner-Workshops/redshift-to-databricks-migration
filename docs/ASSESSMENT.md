# Redshift → Databricks migration assessment

Scope: every SQL asset under `sql/` (7 files: 2 DDL, 3 ETL, 2 BI reports), checked against live
Redshift (`demo-wg` / `demo`) and the Databricks SQL warehouse `565cd2fd713738c4`.
Ranking puts **silent wrong results** first, then errors that fail at runtime, then performance-only items.
Every behaviour below was observed on the live systems unless marked as a recommendation.

## Risk summary

| Rank | Risk | Redshift feature | Where | What happens on Databricks | Severity |
|---|---|---|---|---|---|
| 1 | Blank-padded CHAR comparison | `CHAR(n)` trailing-blank-insensitive `=` / `<>` | `etl/10` L21, `etl/11` L21; CHAR columns in `ddl/02` | `order_status <> 'CANCELLED  '` is true for **every** row: cancelled orders leak into both marts | Critical (silent) |
| 2 | `TRUNC(timestamp)` | one-arg `TRUNC` = timestamp → date | `etl/10` L10, L22; `reports/21` L8 | Databricks `trunc` only truncates dates to year/quarter/month/week; `trunc(ts, 'DD')` returns NULL | High (silent NULL) |
| 3 | `DATEDIFF(day, …)` on timestamps | counts day boundaries crossed | `etl/11` L18 (`active_days`) | `datediff(day, …)` returns whole elapsed days: 23:00 → 01:00 next day is 1 on Redshift, 0 on Databricks | High (silent off-by-one) |
| 4 | DECIMAL `AVG` / division scale | `AVG(DECIMAL(12,2))` keeps scale 2; `DECIMAL / BIGINT` scale 4 | `etl/10` L17, `etl/11` L17, `reports/20` L6 | Databricks returns `decimal(16,6)` / `decimal(38,6)`; live `AVG(order_total)` = 921.92 on Redshift vs 921.928482 on Databricks | High (silent, cent-level) |
| 5 | `GETDATE()` | session timestamp; column `DEFAULT GETDATE()` | `ddl/02` L11, L24; `etl/10` L22; `etl/12` L5, L10; `reports/21` L8 | `getdate()` exists and returns the warehouse session time zone (`Etc/UTC` today); CTAS does not carry column defaults | Medium |
| 6 | `IDENTITY(1,1)` keys | engine-assigned surrogate keys | `ddl/02` L4, L18, L31 | CTAS lands keys as plain `INT`/`BIGINT` with no generator; new rows need an explicit key strategy | Medium |
| 7 | PL/pgSQL stored procedure | `CREATE PROCEDURE … LANGUAGE plpgsql`, `RAISE INFO` | `etl/12` | No PL/pgSQL on Databricks; the procedure also drops `mart.daily_revenue_stage`, which does not exist in Redshift | Medium (fails loudly) |
| 8 | `DECODE` | Oracle-style `DECODE` | `etl/10` L12 | `decode()` exists with the same semantics, including NULL = NULL matching | Low |
| 9 | `DISTSTYLE` / `DISTKEY` / `SORTKEY` | physical distribution and sort | `ddl/02`, `etl/10`, `etl/11` | Syntax error if left in; no direct equivalent | Low (loud, performance only) |
| 10 | DROP + CTAS full refresh | non-atomic rebuild | `etl/10`, `etl/11` | Works, but readers see a missing table between DROP and CREATE | Low |
| 11 | Federation type mapping | `SMALLINT`, `CHAR(n)`, `VARCHAR(n)` | `ddl/02` | `SMALLINT` → `INT`; `CHAR`/`VARCHAR` → `STRING` (padding kept, length limits dropped) | Low |

## Inventory

| File | Objects | Redshift-specific features |
|---|---|---|
| `sql/ddl/01_schemas.sql` | schemas `core`, `mart` | none (`CREATE SCHEMA IF NOT EXISTS` is portable) |
| `sql/ddl/02_core_tables.sql` | `core.customers`, `core.orders`, `core.order_items` | `IDENTITY(1,1)` ×3, `CHAR(n)` ×4 (`customer_code`, `region`, `order_status`, `sku`), `DEFAULT GETDATE()` ×2, `DISTSTYLE KEY` / `DISTKEY` ×3, `SORTKEY` / `COMPOUND SORTKEY` ×3, `SMALLINT` |
| `sql/etl/10_build_daily_revenue.sql` | `mart.daily_revenue` | DROP + CTAS, `DISTSTYLE ALL`, `SORTKEY`, `TRUNC(ts)` ×2, `DECODE`, `GETDATE()`, CHAR padded compare, `DECIMAL` / `COUNT` division |
| `sql/etl/11_build_customer_ltv.sql` | `mart.customer_ltv` | DROP + CTAS, `DISTKEY`, `SORTKEY`, `AVG(DECIMAL)`, `DATEDIFF(day, ts, ts)`, CHAR padded compare |
| `sql/etl/12_sp_refresh_marts.sql` | `mart.sp_refresh_marts()` | PL/pgSQL procedure, `$$` body, `RAISE INFO`, `GETDATE()` |
| `sql/reports/20_region_topline.sql` | region topline report | `AVG` over a DECIMAL column (average of per-customer averages) |
| `sql/reports/21_channel_trend.sql` | 30-day channel trend | `DATEADD(day, …)`, `TRUNC(GETDATE())` |

Live Redshift objects match the repo: `core.customers`, `core.orders`, `core.order_items`,
`mart.customer_ltv`, `mart.daily_revenue`.

## Findings

### 1. Blank-padded CHAR comparison (Critical)

Redshift ignores trailing blanks when comparing `CHAR` values, so `order_status <> 'CANCELLED  '`
(11 characters against a `CHAR(10)` column) excludes cancelled orders. Through federation the
column arrives as a padded `STRING` (`'CANCELLED '`, length 10), and Databricks compares strings
exactly.

| `core.orders` rows passing `order_status <> 'CANCELLED  '` | Count |
|---|---|
| Redshift | 50,577 |
| Databricks (same predicate on the backfilled table) | 60,767 |

A literal translation would add 10,190 cancelled orders and 9,408,910.83 of revenue
(56,022,828.05 − 46,613,917.22) to `mart.daily_revenue` and `mart.customer_ltv`.

Recommendation: compare on `rtrim(order_status) <> 'CANCELLED'` in the converted marts, and decide once
whether `core` keeps padded values (exact copy, current state) or is trimmed at load; every
equality, join and `GROUP BY` on `customer_code`, `region`, `order_status`, `sku` depends on that choice.

### 2. `TRUNC(timestamp)` (High)

`TRUNC(o.order_ts)` is Redshift's timestamp-to-date. On Databricks `trunc()` is a date function
whose format must be year/quarter/month/week; `trunc(TIMESTAMP '2026-10-26 23:57:13', 'DD')`
returns NULL, so a mechanical rewrite empties `order_date` and the `< TRUNC(GETDATE())` cutoff.
Recommendation: `CAST(o.order_ts AS DATE)` (or `date_trunc('DAY', …)` where a timestamp is needed).

### 3. `DATEDIFF(day, …)` on timestamps (High)

Redshift returns the number of day boundaries crossed; Databricks `datediff(day, start, end)`
(`timestampdiff`) returns whole elapsed days.

| `DATEDIFF(day, '2026-01-01 23:00', '2026-01-02 01:00')` | Result |
|---|---|
| Redshift | 1 |
| Databricks `datediff(day, …)` | 0 |

`mart.customer_ltv.active_days` would drift by one for many customers. Recommendation:
`datediff(CAST(max_ts AS DATE), CAST(min_ts AS DATE))`.

### 4. DECIMAL `AVG` and division scale (High)

| Expression on `core.orders` | Redshift | Databricks |
|---|---|---|
| `AVG(order_total)` | 921.92 | 921.928482 (`decimal(16,6)`) |
| `SUM(order_total) / COUNT(*)` | 921.9284 | 921.928482 (`decimal(38,6)`) |
| `ROUND(SUM(order_total) / COUNT(*), 2)` | 921.93 | 921.93 |

Redshift `AVG` over `DECIMAL(12,2)` returns scale 2 and here differs from the cent-rounded mean
(921.93). `mart.customer_ltv.avg_order_value`, `mart.daily_revenue.avg_order_value` and
`reports/20` `aov` will not match to the cent unless the converted SQL pins the result type.
Recommendation: agree the business rule (Redshift's scale-2 value vs. the rounded mean), then cast
explicitly, e.g. `CAST(AVG(order_total) AS DECIMAL(12,2))` and check it against Redshift output in recon.

### 5. `GETDATE()` (Medium)

`getdate()` is available on the warehouse and returns a timestamp in the session time zone
(`Etc/UTC` today). The nightly cutoff `o.order_ts < TRUNC(GETDATE())` only matches Redshift while
the session stays UTC; pin `SET TIME ZONE 'UTC'` in the job or use `current_date()` explicitly.
`DEFAULT GETDATE()` on `created_at` / `loaded_at` is not carried by CTAS; add
`DEFAULT current_timestamp()` (requires the `allowColumnDefaults` table feature) or set it in ingestion.

### 6. `IDENTITY(1,1)` (Medium)

The backfill preserves existing key values as plain integers. For rows written natively in
Databricks, use `GENERATED BY DEFAULT AS IDENTITY (START WITH max+1)` or keep keys assigned
upstream. Neither engine guarantees gap-free identity values, so nothing downstream should
depend on contiguity.

### 7. Stored procedure `mart.sp_refresh_marts` (Medium)

PL/pgSQL with `RAISE INFO` has no direct Databricks equivalent. The body only logs and drops
`mart.daily_revenue_stage`; the mart builds themselves are run by the scheduler in file order.
Recommendation: replace with a Lakeflow job of two SQL tasks (`10` → `11`), and drop the
stage-table step, which has no table behind it.

### 8–11. Low-risk items

- `DECODE`: same result on both engines for the `sales_channel` mapping, including NULL handling;
  a `CASE` expression is clearer in converted code.
- `DISTSTYLE` / `DISTKEY` / `SORTKEY`: remove; consider liquid clustering
  (`CLUSTER BY (order_ts, customer_id)` on `orders`, `CLUSTER BY (order_id)` on `order_items`).
- DROP + CTAS: use `CREATE OR REPLACE TABLE … AS`, which swaps atomically.
- Federation type mapping: `quantity` widens from `SMALLINT` to `INT`; `CHAR`/`VARCHAR` length limits
  are not enforced in Delta. `DATEADD(day, -30, …)` is supported and returns a timestamp.

## Backfill status

`core.customers`, `core.orders`, `core.order_items` are copied into `migration_demo.core` as Delta
tables by CTAS from the foreign catalog `redshift_src` (`migration/backfill/01_core_backfill.sql`).
Values are copied unchanged, including CHAR padding. Parity against live Redshift is checked by
`migration/verify/verify_core_backfill.py` (row counts, distinct keys, sums, averages, min/max
timestamps); all required checks match. `migration_demo.mart` is created and empty, ready for the
converted marts.
