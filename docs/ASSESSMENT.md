# Trino to Databricks migration assessment

Scope: all eight files under `trino/sql`, plus the two catalog definitions that decide where
the data actually lives. Target: Unity Catalog catalog `trino_migration_demo_run4`
(schemas `core`, `ops`, `mart`, raw snapshot in `trino_src`) on the existing SQL warehouse.

## The estate in one paragraph

Trino serves one SQL endpoint over two storage systems: `lake` is a Hive connector over
Parquet files on local disk, `ops` is a PostgreSQL connector over the operational database.
Two ETL files build two marts by joining across both. Three report files read the marts (and
one reads the raw orders table). Nothing reaches Databricks over the network, so the six
tables were exported to CSV, uploaded to a Unity Catalog volume, and loaded from there.

## Risk ranking

Risk is how likely the file is to produce different numbers on Databricks, not how long it
takes to rewrite.

| Rank | File | Risk | Why |
|---|---|---|---|
| 1 | `sql/reports/22_promo_lift.sql` | **High** | `approx_percentile` in Trino is non-deterministic: two runs over unchanged data gave medians of 351.23 and 348.00 for the same promo. It also unnests a MAP with `CROSS JOIN UNNEST(map_entries(...))`, which has no direct Databricks equivalent. Cannot be reconciled to an exact value - see open item. |
| 2 | `sql/etl/11_build_customer_ltv.sql` | **High** | Four separate semantic traps: `date_diff('day', ...)` counts whole 24h intervals while Spark's `datediff()` counts calendar boundaries (differed on 97 of 150 rows before the fix); `array_agg(DISTINCT x ORDER BY x)` needs an explicit sort on Databricks or row order is arbitrary; `avg()` over `DECIMAL(12,2)` keeps scale 2 in Trino but widens to `(16,6)` on Databricks; `arbitrary()` has to become `any_value()`. |
| 3 | `sql/etl/10_build_daily_revenue.sql` | **Medium-high** | `approx_distinct` is approximate in principle (exact at this cardinality, so an exact `COUNT(DISTINCT)` reproduces it and removes the drift); decimal division scale differs; `element_at` on a missing MAP key returns NULL and the surrounding `if()` must keep that branch; the `current_timestamp` day-boundary filter makes the result time-dependent. |
| 4 | `sql/ddl/02_core_tables.sql` | **Medium** | `MAP(VARCHAR, VARCHAR)`, `DECIMAL(5,4)`, `SMALLINT` and Hive partitioning-by-`order_date` all have to be reproduced. The MAP survives CSV only as JSON text and is rebuilt with `from_json`. |
| 5 | `ops-db/init.sql` (source of `ops.public.*`) | **Medium** | `CHAR(12)` and `CHAR(4)` are blank-padded types. Databricks keeps `CHAR(n)` in a table schema but degrades it to `STRING` through any expression, so the mart tables are declared with explicit column types instead of using CTAS. |
| 6 | `sql/reports/20_region_topline.sql` | **Low-medium** | Only `cardinality()` to `size()` plus the `AVG` decimal-scale issue. |
| 7 | `sql/reports/21_channel_trend.sql` | **Low-medium** | `date_add('day', -30, current_date)` to `date_sub(current_date(), 30)`. Result depends on the run date, so before/after must be captured on the same day. |
| 8 | `sql/seed/05_seed_orders.sql` | **Low** | Demo seed data for both `orders` and `order_items`, not migrated. Uses `sequence()`, `random()` and MAP literals that would need rewriting if it ever were. |
| 9 | `sql/ddl/01_schemas.sql` | **Low** | Hive `location` properties disappear entirely under Unity Catalog managed tables. The mart tables have no DDL file - the ETL files create them with `external_location`, which also disappears. |
| 10 | `etc/catalog/lake.properties`, `etc/catalog/ops.properties` | **Low** | No Databricks equivalent needed. Replaced by the CSV export plus volume load, because the workspace cannot reach the Trino stack. |

## What changed in the converted SQL

Everything below is a change in the Databricks SQL only. No file under `trino/` was touched.

- `approx_distinct(order_id)` to `COUNT(DISTINCT order_id)`
- `element_at(attrs, 'promo')` to `attrs['promo']`
- `date_diff('day', a, b)` to `timestampdiff(DAY, a, b)` (not `datediff`)
- `array_agg(DISTINCT tag ORDER BY tag)` to `array_sort(collect_set(tag))`
- `arbitrary(x)` to `any_value(x)`
- `format_datetime(ts, 'yyyy-MM')` to `date_format(ts, 'yyyy-MM')`
- `cardinality(x)` to `size(x)`
- `date_add('day', -30, current_date)` to `date_sub(current_date(), 30)`
- `CROSS JOIN UNNEST(map_entries(attrs)) AS u(k, v)` to `LATERAL VIEW explode(attrs) u AS k, v`
- explicit casts to restore Trino's decimal scales, and explicit column declarations to keep
  `CHAR(4)` / `CHAR(12)` / `TIMESTAMP_NTZ`

## Result

Both marts rebuild from the converted SQL and reconcile exactly against the Trino snapshot:
row counts equal, all 14 per-column aggregates zero-delta, symmetric row diffs empty in both
directions, and reports 20 and 21 zero-delta. Report 22's median is the single open item
(see the PR). Evidence is in `docs/evidence/run-4/`.
