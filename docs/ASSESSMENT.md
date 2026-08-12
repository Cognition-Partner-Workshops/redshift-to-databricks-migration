# Redshift → Databricks Migration Assessment

Inventory of every SQL asset in this repo, risk-ranked by the Redshift-specific
features it uses and how likely each is to change results or fail outright on
Databricks SQL.

## Inventory

| # | Asset | Type | Purpose |
|---|-------|------|---------|
| 1 | `sql/ddl/01_schemas.sql` | DDL | Creates `core` and `mart` schemas |
| 2 | `sql/ddl/02_core_tables.sql` | DDL | `core.customers`, `core.orders`, `core.order_items` |
| 3 | `sql/etl/10_build_daily_revenue.sql` | ETL (nightly) | Rebuilds `mart.daily_revenue` |
| 4 | `sql/etl/11_build_customer_ltv.sql` | ETL (nightly) | Rebuilds `mart.customer_ltv` |
| 5 | `sql/etl/12_sp_refresh_marts.sql` | Stored procedure | Scheduler wrapper `mart.sp_refresh_marts()` |
| 6 | `sql/reports/20_region_topline.sql` | BI report | Region topline from `mart.customer_ltv` |
| 7 | `sql/reports/21_channel_trend.sql` | BI report | 30-day channel trend from `mart.daily_revenue` |
| 8 | `scripts/seed_redshift.py` | Ops script | Seeds the estate via Redshift Data API (stays Redshift-side) |
| 9 | `scripts/drift_loader.py` | Ops script | Lands drift data into Redshift (stays Redshift-side) |

## Risk ranking

Ranked highest-risk first. "Silent" means the query runs on Databricks but
returns different results — the most dangerous class.

### 1. `sql/etl/11_build_customer_ltv.sql` — **CRITICAL (silent data divergence)**
- **Decimal `AVG` truncation**: Redshift *truncates* `AVG(DECIMAL(12,2))` to the
  result scale; Databricks *rounds* (half-up). `avg_order_value` diverges by
  one cent for roughly half of all customers. Requires explicit
  `CAST(FLOOR(AVG(x) * 100) / 100 AS DECIMAL(...))`-style truncation (or
  `SUM/COUNT` with explicit truncation) to preserve parity.
- **CHAR blank-padding compare**: `o.order_status <> 'CANCELLED  '` relies on
  Redshift CHAR(10) blank padding. Databricks has no fixed-width CHAR
  semantics on read via federation/Delta — compare against `TRIM`med values.
- **`DATEDIFF(day, a, b)`**: Redshift 3-arg form vs Databricks
  `datediff(end, start)` (2-arg, reversed order) or `date_diff(unit, start, end)`.
- **`DISTKEY`/`SORTKEY` in CTAS**: syntax error on Databricks; drop (optionally
  replace with `CLUSTER BY` / liquid clustering).

### 2. `sql/etl/10_build_daily_revenue.sql` — **CRITICAL (fails + silent traps)**
- **`TRUNC(timestamp)` → date**: Redshift `TRUNC(o.order_ts)` returns a DATE;
  Databricks `TRUNC` only works on dates with a format arg — use
  `CAST(order_ts AS DATE)` / `DATE(order_ts)`.
- **`DECODE(...)`**: supported in Databricks SQL, but verify the default-arg
  arity; safer as `CASE WHEN`.
- **`GETDATE()`**: not a Databricks function — use `current_timestamp()`
  (and `current_date()` where the DATE truncation is intended).
- **CHAR blank-padded filter**: `<> 'CANCELLED  '` — same trap as above.
- **`DISTSTYLE ALL` / `SORTKEY` in CTAS**: syntax error; drop.

### 3. `sql/ddl/02_core_tables.sql` — **HIGH (rewrite required)**
- **`IDENTITY(1,1)`** on all three tables → Databricks
  `GENERATED ALWAYS AS IDENTITY`. Note: Databricks identity does not guarantee
  gap-free/consecutive values; any logic assuming consecutive IDs must be reviewed.
- **`CHAR(n)` columns** (`customer_code CHAR(12)`, `region CHAR(4)`,
  `order_status CHAR(10)`, `sku CHAR(16)`): Databricks CHAR pads on write but
  downstream comparisons/lengths differ; recommend migrating to `STRING` and
  fixing padded comparisons.
- **`DEFAULT GETDATE()`** → `DEFAULT current_timestamp()` (requires
  `'delta.feature.allowColumnDefaults'`).
- **`DISTSTYLE`/`DISTKEY`/`SORTKEY`/`COMPOUND SORTKEY`**: no equivalent —
  drop; consider liquid clustering for large tables.
- **Types**: `SMALLINT`, `DECIMAL(p,s)`, `BOOLEAN`, `TIMESTAMP` map cleanly.

### 4. `sql/etl/12_sp_refresh_marts.sql` — **HIGH (no direct equivalent pattern)**
- **`CREATE OR REPLACE PROCEDURE ... LANGUAGE plpgsql`**: Databricks SQL
  scripting/procedures differ substantially from plpgsql. Recommend converting
  the scheduler entrypoint to a Databricks Workflow (job) that runs the two
  mart-build statements in order, or a SQL script/notebook.
- **`RAISE INFO`**: no equivalent; replace with job logging.
- **`GETDATE()`** inside the body.

### 5. `sql/reports/21_channel_trend.sql` — **MEDIUM**
- **`DATEADD(day, -30, ...)`** → `date_add(..., -30)` or `... - INTERVAL 30 DAYS`.
- **`TRUNC(GETDATE())`** → `current_date()`.
- Otherwise standard aggregation; correct once `mart.daily_revenue` is correct.

### 6. `sql/reports/20_region_topline.sql` — **LOW**
- ANSI aggregation only; no Redshift-isms. Inherits the decimal-AVG semantics
  of `mart.customer_ltv` (`AVG(avg_order_value)`) — verify to the cent after
  the upstream fix.

### 7. `sql/ddl/01_schemas.sql` — **LOW**
- `CREATE SCHEMA IF NOT EXISTS` is valid; only needs catalog qualification
  under Unity Catalog (`migration_demo.core`, `migration_demo.mart`).

### 8–9. `scripts/seed_redshift.py`, `scripts/drift_loader.py` — **N/A**
- Operate the *source* warehouse via the Redshift Data API; not migrated.
  Retire after cutover.

## Feature-risk matrix

| Redshift feature | Assets affected | Risk | Databricks handling |
|---|---|---|---|
| Decimal `AVG` truncation | 11, (6 downstream) | Critical / silent | explicit truncation of AVG result scale |
| CHAR blank-padding semantics | 2 (DDL), 10, 11 | Critical / silent | migrate to STRING + `TRIM`-based compares |
| `TRUNC(timestamp)` | 10, 21 | High / hard error | `CAST(... AS DATE)` |
| Stored procedure (plpgsql) | 12 | High / hard error | Databricks Workflow / SQL script |
| `IDENTITY(1,1)` | 2 | High | `GENERATED ALWAYS AS IDENTITY` (non-consecutive) |
| `GETDATE()` | 2, 10, 12, 21 | Medium / hard error | `current_timestamp()` / `current_date()` |
| `DISTKEY`/`SORTKEY`/`DISTSTYLE` | 2, 10, 11 | Medium / hard error | drop; optional liquid clustering |
| `DECODE()` | 10 | Low | supported; prefer `CASE WHEN` |
| `DATEADD`/`DATEDIFF` | 11, 21 | Medium | `date_add` / `date_diff(unit, ...)` arg-order fix |

## Recommended migration order

1. Land DDL as Delta tables in `migration_demo.core` (backfill via Lakehouse
   Federation CTAS from `redshift_src`).
2. Convert ETL 10 → 11 (with truncation + padding fixes), reconcile marts to
   the cent against Redshift.
3. Replace stored procedure 12 with a Databricks Workflow.
4. Repoint reports 20–21; verify.
