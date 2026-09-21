# Trino order-analytics estate: migration assessment

Source: `trino/` (Trino cluster; Hive/Parquet `lake` catalog with schemas `core`, `mart`; PostgreSQL `ops` catalog).
Target: Unity Catalog catalog `trino_migration_demo` (schemas `core`, `ops`, `mart`; raw snapshot in `trino_src`), Databricks SQL on the existing serverless warehouse.

## Inventory of `trino/sql`

| # | Asset | Kind | Objects touched | Trino-specific features | Risk |
|---|-------|------|-----------------|-------------------------|------|
| 1 | `etl/11_build_customer_ltv.sql` | Nightly full-refresh CTAS | reads `lake.core.orders`, `ops.public.customers`, `ops.public.customer_tags`; writes `lake.mart.customer_ltv` | cross-catalog join (lake + ops); `array_agg(DISTINCT .. ORDER BY ..)`; `date_diff('day', ts, ts)`; `format_datetime`; `arbitrary`; decimal `avg`/`sum` result scale; `CAST(ARRAY[] AS ARRAY(VARCHAR))`; `external_location` | **High** |
| 2 | `etl/10_build_daily_revenue.sql` | Nightly full-refresh CTAS | reads `lake.core.orders`, `ops.public.customers`; writes `lake.mart.daily_revenue` | cross-catalog join; `element_at` on MAP; `approx_distinct`; `if()`; decimal `/ bigint` result scale; `try_cast`; `date_trunc` returning TIMESTAMP; `current_timestamp` cutoff | **High** |
| 3 | `reports/22_promo_lift.sql` | Report | `lake.core.orders` | `CROSS JOIN UNNEST(map_entries(..))` (MAP + UNNEST); `approx_percentile`; decimal `AVG` scale | **High** |
| 4 | `seed/05_seed_orders.sql` | Seed load | writes `lake.core.orders`, `lake.core.order_items` | `UNNEST(sequence())`; `map(ARRAY, ARRAY)`; `element_at` on ARRAY (1-based); `date_add('minute', ..)`; `format('%05d')`; clock-relative data | Medium (not migrated: data lands as a snapshot, not re-seeded) |
| 5 | `ddl/02_core_tables.sql` | DDL | `lake.core.orders`, `lake.core.order_items` | `MAP(VARCHAR, VARCHAR)`; `TIMESTAMP(3)`; `SMALLINT`; Hive `partitioned_by`, `format = 'PARQUET'` | Medium |
| 6 | `reports/20_region_topline.sql` | Report | `lake.mart.customer_ltv` | `cardinality(array)`; `AVG` of decimal (scale) | Low-Medium |
| 7 | `reports/21_channel_trend.sql` | Report | `lake.mart.daily_revenue` | `date_add('day', -30, current_date)`; timestamp-vs-date comparison | Low |
| 8 | `ddl/01_schemas.sql` | DDL | schemas `lake.core`, `lake.mart` | Hive `location` | Low |
| 9 | `ops-db/init.sql` (Postgres, outside `sql/`) | Source of the `ops` catalog | `ops.public.customers`, `ops.public.customer_tags` | `char(12)`, `char(4)` padded text; `serial`; `text` | Low (landed as snapshot) |

Six data objects are in scope: `lake.core.orders` (5,000 rows), `lake.core.order_items` (12,000), `ops.public.customers` (200), `ops.public.customer_tags` (401), `lake.mart.daily_revenue` (360), `lake.mart.customer_ltv` (150; customers whose every order is CANCELLED drop out of the inner join).

## Feature-by-feature risk and conversion decision

Ranked by how likely a naive syntax swap gives a *different answer*.

1. **Decimal arithmetic scale (High).** Trino keeps the input scale: `avg(DECIMAL(12,2))` is `DECIMAL(12,2)`, `sum(DECIMAL(12,2))` is `DECIMAL(38,2)`, and `DECIMAL(38,2) / BIGINT` is `DECIMAL(38,6)` (verified with `DESCRIBE lake.mart.daily_revenue`); each is rounded half-up. Databricks widens differently: `avg` gives scale 6, `sum` gives `DECIMAL(22,2)`, division gives `DECIMAL(38,6)`. Left alone, `customer_ltv.avg_order_value` and the report averages carry four extra decimals and never match the Trino snapshot. Conversion: compute in Databricks, then `CAST(.. AS DECIMAL(p,s))` to the Trino result type; the cast rounds half-up like Trino. Double rounding is safe here because every quotient is cents divided by a row count far below 10^5, so the 6-place intermediate can never land within 5e-7 of a half-cent boundary without being exactly on it.
2. **`date_diff('day', ts1, ts2)` (High).** Trino returns whole elapsed 24-hour periods (`(millis2 - millis1) / 86,400,000`, truncated). Databricks `datediff(end, start)` counts calendar-date boundaries, so two timestamps 23 hours apart across midnight give 0 in Trino and 1 in Databricks. Conversion: `(unix_millis(last) - unix_millis(first)) DIV 86400000`.
3. **`approx_distinct` / `approx_percentile` (High).** Different sketch implementations (Trino HyperLogLog and T-digest vs Databricks HLL++ and KLL-style quantiles) are not guaranteed to agree. `order_count` and `avg_order_value` in `daily_revenue` depend on `approx_distinct(order_id)`; the report median depends on `approx_percentile`. Decision: `order_id` is unique per row, so `COUNT(DISTINCT order_id)` is the exact value the approximation estimates; the recon proves whether Trino's estimate was exact on this data. For the median, `approx_percentile` is converted to `percentile_approx` and its output is compared against the Trino result; a difference is reported as an open item, not hidden.
4. **`array_agg(DISTINCT tag ORDER BY tag)` (High).** Databricks `collect_list`/`collect_set` have no `ORDER BY` and no ordering guarantee. Conversion: `array_sort(collect_set(tag))` (tags are plain ASCII, so Databricks and Trino sort the same way). Empty arrays: `coalesce(.., CAST(ARRAY[] AS ARRAY(VARCHAR)))` becomes `coalesce(.., CAST(array() AS ARRAY<STRING>))`.
5. **MAP + UNNEST (High).** `CROSS JOIN UNNEST(map_entries(attrs)) AS u(k, v)` becomes `LATERAL VIEW explode(attrs) u AS attr_key, attr_value`. `element_at(map, key)` becomes `try_element_at(attrs, 'promo')`: under Databricks ANSI mode a plain `attrs['promo']`/`element_at` raises on a missing key, while Trino returns NULL. The `MAP(VARCHAR,VARCHAR)` column itself is landed as `MAP<STRING,STRING>` by exporting the map as JSON text from Trino and `from_json`-ing it on load (CSV cannot carry a map natively).
6. **Cross-catalog joins (Medium).** `lake.core.* JOIN ops.public.*` spans a Hive catalog and a Postgres catalog. The workspace cannot reach the Trino cluster or the Postgres instance, so both sides are landed into one UC catalog (`core`, `ops`) and the join becomes an ordinary same-catalog join. Postgres `char(4)`/`char(12)` values arrive with their padding intact and are stored as `CHAR(4)`/`CHAR(12)`.
7. **`format_datetime(ts, 'yyyy-MM')` (Medium).** Joda pattern vs Databricks `date_format` (Java `DateTimeFormatter`); `yyyy-MM` means the same in both. Other patterns (`e`, `Z`, `'T'`) would not.
8. **`date_trunc('day', ts)` type (Medium).** Both return TIMESTAMP, so `daily_revenue.order_date` stays a midnight timestamp and report 21's `order_date >= <date>` comparison coerces the same way. `TIMESTAMP(3)` (no time zone) maps to `TIMESTAMP_NTZ`.
9. **Clock-relative logic (Medium).** Seed, ETL cutoff (`order_ts < date_trunc('day', current_timestamp)`) and report 21 (`current_date - 30`) all depend on the run date. Trino and the warehouse both run in UTC; the snapshot, mart rebuild and reports are all executed on the same UTC day so the cutoffs agree.
10. **`arbitrary()`, `if()`, `cardinality()`, `try_cast` (Low).** Map to `any_value`, `IF`, `size`, `try_cast`.
11. **Hive storage clauses (Low).** `WITH (format='PARQUET', partitioned_by=..., external_location=...)` are dropped; UC managed Delta tables replace them. `DROP TABLE; CREATE TABLE .. AS` full refresh becomes `CREATE OR REPLACE TABLE .. AS`.

## Landing approach

The Trino cluster is not reachable from the workspace, so the six objects are exported from Trino as CSV (`recon/trino/export_snapshot.sql`), uploaded to UC volume `trino_migration_demo.trino_src.landing` through the Files API, and loaded with `read_files` and explicit casts into `trino_src` (raw snapshot, Trino types). `core` and `ops` are then populated from `trino_src`; `mart` is rebuilt from `core`/`ops` by the converted ETL and reconciled against the `trino_src` copies of the two Trino-built marts.
