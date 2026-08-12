# Redshift → Databricks Migration Assessment

Inventory and risk ranking of every SQL asset in this repository, ranked by how
hard each is to migrate faithfully to Databricks SQL.

## Risk Summary

| Rank | Asset | Type | Risk | Key Redshift-specific features |
|---|---|---|---|---|
| 1 | `sql/etl/12_sp_refresh_marts.sql` | Stored procedure | **High** | PL/pgSQL procedure, `RAISE INFO`, `GETDATE()` — no direct Databricks equivalent; must be re-platformed as a job/workflow |
| 2 | `sql/etl/10_build_daily_revenue.sql` | Nightly ETL | **High** | `DECODE`, `TRUNC(timestamp)`, `GETDATE()`, CHAR(10) blank-padded comparison (`<> 'CANCELLED  '`), `DISTSTYLE ALL`/`SORTKEY` |
| 3 | `sql/ddl/02_core_tables.sql` | DDL | **Medium-High** | `IDENTITY(1,1)`, `CHAR(n)` blank-padding semantics, `GETDATE()` defaults, `DISTSTYLE`/`DISTKEY`/`SORTKEY` |
| 4 | `sql/etl/11_build_customer_ltv.sql` | Nightly ETL | **Medium** | `DATEDIFF(day, ...)` argument order, `AVG(DECIMAL)` truncation semantics, blank-padded CHAR filter, `DISTKEY`/`SORTKEY` |
| 5 | `sql/reports/21_channel_trend.sql` | BI report | **Low-Medium** | `DATEADD(day, -30, ...)`, `TRUNC(GETDATE())` |
| 6 | `sql/reports/20_region_topline.sql` | BI report | **Low** | Standard SQL; only indirect dependence on upstream AVG semantics |
| 7 | `sql/ddl/01_schemas.sql` | DDL | **Low** | Plain `CREATE SCHEMA`; maps 1:1 under a Unity Catalog catalog |

## Asset-by-Asset Detail

### 1. `sql/etl/12_sp_refresh_marts.sql` — stored procedure (High)
- Redshift PL/pgSQL (`CREATE OR REPLACE PROCEDURE ... LANGUAGE plpgsql`) is not
  supported in Databricks SQL. The orchestration wrapper must become a
  Databricks Job / Workflow (or a notebook) that runs the mart build steps in
  numeric order (10, 11).
- `RAISE INFO` logging maps to job/task logging, not SQL.
- `GETDATE()` → `current_timestamp()`.

### 2. `sql/etl/10_build_daily_revenue.sql` — nightly ETL (High)
- `DECODE(expr, v1, r1, v2, r2, default)` → `CASE`/`decode()` (Databricks has a
  `decode` function with matching semantics, but NULL-matching behavior must be
  checked).
- `TRUNC(o.order_ts)` (timestamp → date) → `CAST(order_ts AS DATE)` or
  `date_trunc('DAY', ...)`; Databricks `trunc()` only accepts date + format.
- `o.order_status <> 'CANCELLED  '` relies on CHAR(10) blank-padding. In
  Databricks the federated CHAR values arrive as strings; comparison literals
  must preserve (or trim) padding consistently — a classic silent-wrong-results
  hazard.
- `DISTSTYLE ALL` / `SORTKEY` have no direct equivalent; drop them (optionally
  replace with liquid clustering / `OPTIMIZE ZORDER`).
- `GETDATE()` → `current_timestamp()`; `TRUNC(GETDATE())` → `current_date()`.
- `SUM/COUNT DISTINCT` and `NULLIF` port cleanly, but DECIMAL division scale
  differs between engines and should be validated to the cent.

### 3. `sql/ddl/02_core_tables.sql` — core DDL (Medium-High)
- `IDENTITY(1,1)` → `GENERATED ALWAYS AS IDENTITY` (Delta); note Redshift
  IDENTITY does not guarantee gap-free/ordered values, so downstream logic must
  not rely on ordering.
- `CHAR(12)/CHAR(4)/CHAR(10)/CHAR(16)`: Redshift blank-pads and compares with
  padding; Databricks CHAR is a fixed-length type padded on write but
  federated reads surface padded strings. Every equality/inequality against
  CHAR literals must be audited (see ETL 10/11).
- `DEFAULT GETDATE()` → `DEFAULT current_timestamp()` (needs
  `delta.feature.allowColumnDefaults`).
- `DISTSTYLE KEY / DISTKEY / SORTKEY / COMPOUND SORTKEY`: physical-layout hints
  with no Delta equivalent; drop, and tune with clustering if needed.
- `SMALLINT`, `DECIMAL(p,s)`, `BOOLEAN`, `DATE`, `TIMESTAMP` map directly.

### 4. `sql/etl/11_build_customer_ltv.sql` — nightly ETL (Medium)
- `DATEDIFF(day, start, end)` — Databricks `datediff(end, start)` reverses the
  argument order and only does days; use `datediff(end, start)` or
  `date_diff(DAY, start, end)` carefully.
- `AVG(order_total)` on DECIMAL(12,2): Redshift returns DECIMAL with the same
  scale (truncating), Databricks widens scale — cent-level differences will
  appear in `avg_order_value` unless the result is explicitly cast/rounded.
- Blank-padded `'CANCELLED  '` filter as in asset 2.
- `DISTKEY/SORTKEY` dropped as above.

### 5. `sql/reports/21_channel_trend.sql` — BI report (Low-Medium)
- `DATEADD(day, -30, TRUNC(GETDATE()))` → `date_add(current_date(), -30)` /
  `current_date() - INTERVAL 30 DAYS`.
- Otherwise standard aggregation over `mart.daily_revenue`.

### 6. `sql/reports/20_region_topline.sql` — BI report (Low)
- Standard SQL; ports as-is. `AVG(avg_order_value)` inherits the upstream
  DECIMAL-scale considerations from asset 4.

### 7. `sql/ddl/01_schemas.sql` — schemas (Low)
- `CREATE SCHEMA IF NOT EXISTS core|mart` maps directly to schemas inside the
  `migration_demo` Unity Catalog catalog.

## Cross-Cutting Risks

1. **CHAR blank-padding**: the single most likely source of silent wrong
   results (status filters, region/code joins). Mitigation: trim on ingest or
   normalize comparison literals, then reconcile row counts per filter.
2. **DECIMAL AVG/division scale**: reconcile SUM/AVG to the cent between
   engines before cutover.
3. **IDENTITY columns**: backfill must preserve existing key values (federated
   CTAS does); only new inserts need Delta identity generation.
4. **Physical tuning keys** (DISTKEY/SORTKEY/DISTSTYLE): safe to drop; revisit
   with clustering only if performance requires.
5. **Procedural orchestration**: move the `sp_refresh_marts` wrapper to a
   Databricks Workflow running ETL 10 then 11.
