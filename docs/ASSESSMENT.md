# Redshift → Databricks Migration Assessment

Scope: every SQL asset under `sql/` in this repository, assessed for migration fidelity risk when converting from Redshift (PL/pgSQL dialect, Redshift Serverless) to Databricks SQL (Delta Lake, Unity Catalog).

## Risk summary

| Rank | Asset | Type | Risk | Primary hazards |
|------|-------|------|------|-----------------|
| 1 | `sql/etl/12_sp_refresh_marts.sql` | Stored procedure | **High** | PL/pgSQL procedure + `RAISE INFO`; no direct Databricks SQL equivalent — must be re-architected as a Workflow/Job orchestrating the mart builds |
| 2 | `sql/etl/10_build_daily_revenue.sql` | ETL (drop + CTAS) | **High** | Blank-padded `CHAR(10)` status comparison (`<> 'CANCELLED  '`), `DECODE`, `TRUNC(timestamp)`, `GETDATE()`, `DISTSTYLE ALL`/`SORTKEY` physical hints |
| 3 | `sql/etl/11_build_customer_ltv.sql` | ETL (drop + CTAS) | **Medium-High** | `DATEDIFF(day, start, end)` argument order/semantics, blank-padded `CHAR` comparison, `DISTKEY`/`SORTKEY` hints |
| 4 | `sql/ddl/02_core_tables.sql` | DDL | **Medium** | `IDENTITY(1,1)` columns, `CHAR(n)` blank-padding semantics, `GETDATE()` column defaults, `DISTSTYLE`/`DISTKEY`/`SORTKEY` |
| 5 | `sql/reports/21_channel_trend.sql` | BI report | **Medium** | `DATEADD(day, -30, TRUNC(GETDATE()))` — function names and date typing differ |
| 6 | `sql/reports/20_region_topline.sql` | BI report | **Low** | ANSI-portable aggregate query; only output-formatting differences |
| 7 | `sql/ddl/01_schemas.sql` | DDL | **Low** | Direct mapping to Unity Catalog schemas |

## Asset-by-asset detail

### 1. `sql/etl/12_sp_refresh_marts.sql` — High
A PL/pgSQL stored procedure (`mart.sp_refresh_marts`) invoked nightly by the customer's scheduler. Databricks SQL has no PL/pgSQL runtime and `RAISE INFO` has no equivalent, so this cannot be translated statement-for-statement. The orchestration role (run mart builds `10` then `11` in numeric order, emit start/finish log lines) must move to a Databricks Workflow (job with sequential SQL tasks) or a notebook. This is the highest-risk asset because the migration changes the operational model (scheduler → Workflows), not just SQL syntax.

### 2. `sql/etl/10_build_daily_revenue.sql` — High
Drop + CTAS rebuild of `mart.daily_revenue`. Hazards:
- `o.order_status <> 'CANCELLED  '` relies on Redshift `CHAR(10)` blank padding. In Databricks, if the column lands as `STRING` the trailing-blank literal comparison silently changes semantics; safest conversion is `rtrim(order_status) <> 'CANCELLED'`.
- `DECODE(...)` → `CASE WHEN` (Databricks has no `DECODE` with default argument in this form).
- `TRUNC(o.order_ts)` (timestamp→date) → `CAST(order_ts AS DATE)` or `date_trunc`; Redshift `TRUNC` on a timestamp returns a DATE, Databricks `trunc()` is for dates/numbers with a format argument.
- `GETDATE()` → `current_timestamp()`; the `o.order_ts < TRUNC(GETDATE())` cutoff must become `order_ts < current_date()` to preserve the "exclude today" boundary.
- `DISTSTYLE ALL` / `SORTKEY` are physical hints with no Delta equivalent; drop them (optionally `OPTIMIZE ... ZORDER BY` later).

### 3. `sql/etl/11_build_customer_ltv.sql` — Medium-High
Drop + CTAS rebuild of `mart.customer_ltv`. Hazards:
- `DATEDIFF(day, MIN(o.order_ts), MAX(o.order_ts))`: Redshift signature is `DATEDIFF(unit, start, end)`; Databricks `datediff(end, start)` reverses argument order and counts day boundaries — must convert carefully or use `datediff(DAY, start, end)` (Databricks 3-arg form) and validate boundary behavior.
- Same blank-padded `'CANCELLED  '` comparison as asset 2.
- `DISTKEY`/`SORTKEY` hints must be dropped.

### 4. `sql/ddl/02_core_tables.sql` — Medium
Core table DDL. Hazards:
- `IDENTITY(1,1)` → Delta `GENERATED ALWAYS AS IDENTITY` (values are unique but not guaranteed consecutive; any logic assuming gap-free IDs breaks).
- `CHAR(12)`/`CHAR(4)`/`CHAR(10)`/`CHAR(16)` blank-padding: Databricks `CHAR(n)` pads on write but comparisons via federation/CTAS may surface as `STRING` with trailing blanks preserved — downstream predicates must not assume either behavior.
- `GETDATE()` defaults → `DEFAULT current_timestamp()` (requires `delta.feature.allowColumnDefaults`).
- `DISTSTYLE`/`DISTKEY`/`SORTKEY`/`COMPOUND SORTKEY` dropped.

### 5. `sql/reports/21_channel_trend.sql` — Medium
30-day channel trend. `DATEADD(day, -30, TRUNC(GETDATE()))` → `date_add(current_date(), -30)` or `current_date() - INTERVAL 30 DAYS`. Redshift `TRUNC(GETDATE())` yields a timestamp-formatted date in some client outputs; report-parity diffs must normalize date rendering.

### 6. `sql/reports/20_region_topline.sql` — Low
Pure ANSI aggregates over `mart.customer_ltv`. Only decimal precision/rendering differences expected in output parity checks.

### 7. `sql/ddl/01_schemas.sql` — Low
`CREATE SCHEMA IF NOT EXISTS core|mart` maps directly to Unity Catalog schemas under the target catalog.

## Cross-cutting concerns
- **Drop + CTAS refresh pattern**: both marts are fully rebuilt nightly. Delta `CREATE OR REPLACE TABLE` preserves this pattern transactionally (better than Redshift's `DROP` + `CREATE`, which leaves a window with no table).
- **Numeric execution order**: the scheduler runs scripts in numeric order (`10` before `11`). The Databricks Workflow must encode this dependency explicitly.
- **Blank-padded CHAR comparisons** are the highest silent-corruption risk in the estate: a naive translation returns different row sets with no error.
- **Decimal types**: `DECIMAL(12,2)`/`DECIMAL(10,2)`/`DECIMAL(5,4)` map directly; aggregates should be verified to the cent during reconciliation.

## Recommended migration order
1. Land `core.customers`, `core.orders`, `core.order_items` into the lakehouse via Lakehouse Federation CTAS (no logic conversion risk; verifiable row-for-row).
2. Convert and validate the two mart builds (assets 2–3) with row-count and aggregate reconciliation against Redshift.
3. Replace the stored-procedure orchestration (asset 1) with a Databricks Workflow.
4. Port the BI reports (assets 5–6) and run output parity checks.
