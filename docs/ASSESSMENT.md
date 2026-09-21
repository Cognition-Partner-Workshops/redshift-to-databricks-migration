# Trino estate: migration assessment

Scope: everything under `trino/sql` (8 files) plus the two catalogs behind it: `lake` (Hive metastore over
Parquet files under `file:///data/warehouse`) and `ops` (PostgreSQL via the Trino `postgresql` connector).
Target: Unity Catalog catalog `trino_migration_demo`, schemas `core`, `ops`, `mart`, plus `trino_src` for the
raw snapshot. Source is read-only; the workspace cannot reach Trino, so data moves as CSV through a UC volume.

Risk means "how likely is the converted SQL to return a different answer than Trino if translated literally",
not "how hard is it to type".

## Ranking

| Rank | File | Risk | Why | Conversion |
|---|---|---|---|---|
| 1 | `sql/reports/22_promo_lift.sql` | **High** | `approx_percentile(order_total, 0.5)` in Trino is a randomized quantile digest: it returned four different `median_order_total` values across four runs on the same data (349.6 to 351.4, and the `ORDER BY median_order_total DESC` row order changed too). There is no Trino value to reconcile to. `CROSS JOIN UNNEST(map_entries(attrs))` has no direct equivalent. | `LATERAL VIEW explode(attrs)`; `percentile_approx(order_total, 0.5, 10000)`, which is deterministic and returns a true middle order value. Recon checks the result sits between the 625th and 626th ordered values per promo and that `AVG` matches exactly. Recorded as the one open item. |
| 2 | `sql/etl/11_build_customer_ltv.sql` | **High** | `date_diff('day', ts, ts)` in Trino counts whole 24-hour spans, not calendar-day boundaries; a literal `datediff()` would change `active_days` for 94 of 150 customers. `avg(DECIMAL(12,2))` keeps scale 2 in Trino but widens to `DECIMAL(16,6)` in Databricks. `array_agg(DISTINCT tag ORDER BY tag)` needs `array_sort(collect_set())`. `arbitrary` -> `any_value`, `format_datetime` -> `date_format`. Cross-connector join (Hive + Postgres) collapses to one catalog. Databricks CTAS turns `CHAR`/`VARCHAR` into `STRING` even with an explicit cast, so the mart must be declared before it is filled. | `floor((unix_millis(last) - unix_millis(first)) / 86400000)`; explicit casts to `DECIMAL(38,2)`, `DECIMAL(12,2)`, `CHAR(12)`, `CHAR(4)`; `INSERT OVERWRITE` into a Delta table declared with the Trino types instead of `DROP` + CTAS to an external Parquet path. |
| 3 | `sql/etl/10_build_daily_revenue.sql` | **Medium** | `approx_distinct(order_id)` is an HLL estimate. On this data it equals the exact count for all 360 mart rows, so `COUNT(DISTINCT)` reproduces the snapshot; on larger data the Trino mart itself would be approximate. `SUM / approx_distinct` yields `DECIMAL(38,6)` in Trino; Databricks decimal division rules give a different scale unless the numerator is cast to `DECIMAL(38,2)` first. `element_at` on a missing key raises under ANSI mode. `date_trunc('day', current_timestamp)` filter depends on run time. | `COUNT(DISTINCT)`, `try_element_at`, cast-before-divide, `CAST(... AS CHAR(4))` / `VARCHAR(11)` to keep the Trino column types. Both estates were run on the same UTC day so the `current_timestamp` filter matches. |
| 4 | `sql/ddl/02_core_tables.sql` | **Medium** | `MAP(VARCHAR, VARCHAR)` and `TIMESTAMP(3)`; Hive `partitioned_by = ARRAY['order_date']` and `format = 'PARQUET'` table properties. Trino `SMALLINT`, `DECIMAL(5,4)`. | `MAP<STRING, STRING>`, `TIMESTAMP` (millisecond values preserved), Delta with `CLUSTER BY (order_date)`; other types map one-to-one. |
| 5 | `ops-db/init.sql` (source of `ops.public.*`) | **Medium** | Postgres `char(12)`, `char(4)`, `varchar(120/160)`, `serial`, `text`, `timestamp`. `CHAR(4)` must stay `CHAR(4)`; Databricks CTAS silently turns it into `STRING`, so the tables are created with explicit DDL and loaded with `INSERT`. PK/FK constraints are informational in Databricks. | `databricks/ddl/03_ops_tables.sql` with `CHAR`/`VARCHAR` kept and informational PK/FK. |
| 6 | `sql/reports/21_channel_trend.sql` | **Low** | `date_add('day', -30, current_date)` argument order differs. `order_date` is a `TIMESTAMP` compared to a `DATE`; both engines promote the date. | `date_add(current_date(), -30)`. Output identical row for row. |
| 7 | `sql/reports/20_region_topline.sql` | **Low** | `AVG(DECIMAL(12,2))` scale widening (2 -> 6). `cardinality(array)` exists in both. | `CAST(AVG(...) AS DECIMAL(12,2))`. Output identical row for row. |
| 8 | `sql/ddl/01_schemas.sql` | **Low** | Schema locations point at local Hive paths (`file:///data/warehouse/...`). | Catalog + schemas + volume in `databricks/ddl/01_schemas.sql`; no locations. |
| 9 | `sql/seed/05_seed_orders.sql` | **Not migrated** | Deterministic seed generator using Trino `sequence`/`UNNEST`/`map`/`date_add`. It only exists to populate the demo; the data itself is what moves. | Data landed from the Trino export instead (`databricks/landing/`). If a Databricks-side generator is ever needed, `explode(sequence(...))` and `map()` cover it. |

## Cross-cutting

- **Two storage systems, one SQL endpoint** becomes one catalog with three schemas. No federation is needed because
  the Postgres data is small and static in this estate; if `ops` keeps changing, Lakehouse Federation to Postgres is the
  follow-up.
- **Types kept exactly**: `attrs MAP<STRING,STRING>`, `region CHAR(4)`, `customer_code CHAR(12)`, `DECIMAL(12,2)`,
  `DECIMAL(38,2)`, `DECIMAL(38,6)`, `ARRAY<STRING>`. `TIMESTAMP(3)`/`TIMESTAMP(6)` become `TIMESTAMP` (microsecond
  precision, so nothing is lost).
- **Marts**: Trino drops and rewrites Parquet folders under `/data/warehouse/mart`; Databricks declares the marts once
  (`databricks/ddl/04_mart_tables.sql`) and the ETL does `INSERT OVERWRITE`, which is atomic and keeps Delta history.
- **Run-time dependence**: `10_build_daily_revenue.sql` filters on `current_timestamp` and `21_channel_trend.sql` on
  `current_date`. Snapshot and rebuild both ran on 2026-09-21 UTC, so they agree; a rebuild on a later day would
  legitimately include more rows.
