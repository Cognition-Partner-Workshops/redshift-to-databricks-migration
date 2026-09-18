# Redshift → Databricks migration assessment

Scope: every SQL asset under `sql/` (7 files), assessed for how faithfully it can be reproduced in
Databricks SQL. Ranked by conversion risk — the chance that a literal translation compiles but
returns different numbers, or does not translate at all.

## Risk summary

| Rank | Asset | Risk | Main blockers |
|---|---|---|---|
| 1 | `sql/etl/12_sp_refresh_marts.sql` | High | PL/pgSQL procedure (`$$ ... $$`, `RAISE INFO`); no equivalent object — becomes orchestration |
| 2 | `sql/etl/10_build_daily_revenue.sql` | High | `CHAR` blank-padded compare `<> 'CANCELLED  '`, `DECODE`, `TRUNC(GETDATE())`, `DISTSTYLE ALL`/`SORTKEY`, drop+CTAS |
| 3 | `sql/ddl/02_core_tables.sql` | Medium | `IDENTITY(1,1)`, `DISTKEY`/`DISTSTYLE`/`COMPOUND SORTKEY`, `CHAR(n)` padding semantics |
| 4 | `sql/etl/11_build_customer_ltv.sql` | Medium | Same `CHAR` compare, `DATEDIFF(day, a, b)` argument order, decimal scale on `AVG` |
| 5 | `sql/reports/21_channel_trend.sql` | Medium-low | `DATEADD(day, -30, TRUNC(GETDATE()))`, date vs timestamp typing of `order_date` |
| 6 | `sql/reports/20_region_topline.sql` | Low | Average-of-average decimal scale only |
| 7 | `sql/ddl/01_schemas.sql` | Low | Schema creation inside a Unity Catalog catalog |

## Cross-cutting issues

**Blank-padded `CHAR` comparisons are the biggest correctness trap.** `core.orders.order_status` is
`CHAR(10)`, so Redshift stores `'CANCELLED '` padded to 10 characters and the ETL filters with
`order_status <> 'CANCELLED  '`. Databricks has no blank-padded `CHAR` in practice — values land as
`STRING`. A literal translation still compiles, but the comparison no longer matches any row, so
cancelled orders silently flow into the marts and revenue comes out high. Every such compare must
become `TRIM(order_status) <> 'CANCELLED'`. The same applies to `customers.region CHAR(4)` and
`order_items.sku CHAR(16)` when they are joined or grouped.

**Distribution and sort keys have no target equivalent.** `DISTKEY`, `DISTSTYLE`, `SORTKEY`, and
`COMPOUND SORTKEY` are Redshift storage tuning. In Delta they are dropped; liquid clustering
(`CLUSTER BY`) on the former sort key is the closest behavioural match. `IDENTITY(1,1)` maps to
`GENERATED ALWAYS AS IDENTITY`, but for a migration the identity values must be carried over as
plain values rather than regenerated.

**Redshift-only date functions.** `GETDATE()` → `current_timestamp()`, `TRUNC(ts)` →
`date_trunc('DAY', ts)` or `CAST(ts AS DATE)` (note `TRUNC` returns a timestamp in Redshift Data API
output, so date columns need an explicit cast to stay comparable), `DATEADD(day, -30, x)` →
`date_add(x, -30)`, `DECODE(...)` → `CASE`. `DATEDIFF(day, a, b)` exists in Databricks SQL with the
same three-argument form, so `active_days` is safe.

**Decimal scale drift.** `SUM(order_total) / NULLIF(COUNT(DISTINCT order_id), 0)` and `AVG(...)` on
`DECIMAL(12,2)` produce different result scales in the two engines. Comparisons must round to a
fixed scale (cents) or the recon reports false mismatches.

**Full-refresh ETL pattern.** Both mart builds are `DROP TABLE` + `CREATE TABLE AS`. In Databricks
this becomes `CREATE OR REPLACE TABLE ... AS SELECT`, which is atomic and keeps table history — a
behavioural improvement, and it removes the window where the mart does not exist.

## Per-asset notes

### 1. `sql/etl/12_sp_refresh_marts.sql` — High
A PL/pgSQL stored procedure the customer's scheduler calls nightly. Databricks SQL has no
`CREATE PROCEDURE ... LANGUAGE plpgsql`, no `RAISE INFO`, and no `$$` body. The wrapper's real job
is ordering (run `10_` then `11_`), so it should become a Lakeflow job with one task per mart build
and the dependency expressed between tasks. Logging moves to job run output.

### 2. `sql/etl/10_build_daily_revenue.sql` — High
Carries almost every cross-cutting issue at once: the padded `CANCELLED` filter, `DECODE` for
`channel_group`, `TRUNC(o.order_ts)` for the grain, `o.order_ts < TRUNC(GETDATE())` as the
"complete days only" cut-off, and `DISTSTYLE ALL`/`SORTKEY` on the target. The cut-off also makes
the mart time-dependent: a rebuild on either side at different moments produces different row
counts, so recon must rebuild both sides in the same window.

### 3. `sql/ddl/02_core_tables.sql` — Medium
Three tables with `IDENTITY` keys, `CHAR`/`VARCHAR` mix, `DECIMAL(12,2)` and `DECIMAL(5,4)` money
and rate columns, and Redshift-only physical clauses. Types map cleanly (`SMALLINT`, `BIGINT`,
`DECIMAL`, `BOOLEAN`, `TIMESTAMP` all exist); the risk is the padding semantics of `CHAR` and
silently dropping the tuning clauses.

### 4. `sql/etl/11_build_customer_ltv.sql` — Medium
Straight aggregate per customer. Risks are the padded status filter, `AVG(order_total)` scale, and
`DATEDIFF(day, MIN(...), MAX(...))`. Note the `JOIN` means customers with no orders are absent from
the mart in both engines — preserve that rather than "fixing" it to a left join.

### 5. `sql/reports/21_channel_trend.sql` — Medium-low
`DATEADD(day, -30, TRUNC(GETDATE()))` needs translating, and the comparison is only stable if
`order_date` has the same type on both sides. Because the window is relative to "today", report
parity checks must run against the same as-of date.

### 6. `sql/reports/20_region_topline.sql` — Low
Plain `GROUP BY region` over the LTV mart. The only difference is decimal scale on
`AVG(avg_order_value)`; `region` being `CHAR(4)` means grouped labels may carry trailing spaces on
the Redshift side, so trim before diffing.

### 7. `sql/ddl/01_schemas.sql` — Low
`CREATE SCHEMA IF NOT EXISTS core|mart` maps directly to schemas inside the `migration_demo` Unity
Catalog catalog.

## Landing approach

Core data is landed with Lakehouse Federation rather than an export/copy: the `redshift_src` foreign
catalog reads Redshift live, and each core table is materialised as Delta with
`CREATE OR REPLACE TABLE migration_demo.core.<t> AS SELECT * FROM redshift_src.core.<t>`
(`databricks/backfill/01_core_backfill.sql`). That keeps the copy repeatable, needs no S3 staging,
and leaves the federated catalog available as the reference for recon. Marts are deliberately not
backfilled — they are rebuilt from converted ETL so the conversion itself is what gets verified.

`scripts/verify_backfill.py` checks the landed tables against live Redshift: row counts, distinct
key counts, money sums to the cent, and min/max timestamps per table, printed side by side. It
exits non-zero on any mismatch.
