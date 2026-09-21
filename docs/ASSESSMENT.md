# Trino estate assessment

This run keeps the source shape and moves the analytical tables into Delta.
The operational Postgres side is represented by `trino_migration_demo.ops`.
The snapshot is stored under `trino_migration_demo.trino_src`.

## Risk-ranked inventory

| File | Trino-specific constructs | Risk | Conversion decision |
| --- | --- | --- | --- |
| `trino/etc/config.properties` | Single-node coordinator and discovery settings | L | Runtime-only; no SQL conversion |
| `trino/etc/node.properties` | Trino node identity | L | Runtime-only; no target object |
| `trino/etc/jvm.config` | Trino JVM flags | L | Runtime-only; no target object |
| `trino/etc/catalog/lake.properties` | Hive file metastore and Parquet defaults | M | Replace with Delta tables in the migration catalog |
| `trino/etc/catalog/ops.properties` | PostgreSQL JDBC catalog | H | Snapshot into `ops` tables for this run |
| `trino/ops-db/init.sql` | PostgreSQL serial, `char(4)`, and `generate_series` | M | Load the exported rows; preserve raw `NORT`/`SOUT` values |
| `trino/sql/ddl/01_schemas.sql` | Catalog-qualified schema locations | L | Create target `core`, `mart`, and `ops` schemas |
| `trino/sql/ddl/02_core_tables.sql` | Hive `WITH`, Parquet, and `partitioned_by` | M | Use Delta and `PARTITIONED BY (order_date)` |
| `trino/sql/seed/05_seed_orders.sql` | `UNNEST(sequence())`, `element_at`, and map literals | M | Snapshot the materialized rows; no seed port needed |
| `trino/sql/etl/10_build_daily_revenue.sql` | `approx_distinct`, `if`, `try_cast`, and Hive CTAS properties | M | Use `COUNT(DISTINCT)`, Delta CTAS, and native equivalents |
| `trino/sql/etl/11_build_customer_ltv.sql` | `array_agg` ordering, `date_diff`, `format_datetime`, `arbitrary` | M | Use `array_sort(collect_set)`, `datediff`, `date_format`, and `any_value` |
| `trino/sql/reports/20_region_topline.sql` | `cardinality` | L | Use `size(tags)` |
| `trino/sql/reports/21_channel_trend.sql` | `date_add` with a negative interval | L | Use `date_sub(current_date(), 30)` |
| `trino/sql/reports/22_promo_lift.sql` | `CROSS JOIN UNNEST(map_entries(attrs))` and `approx_percentile` | H | Use `LATERAL VIEW explode` and `percentile_approx` |
| `trino/Makefile` | Container-local CLI execution and file ordering | L | Retain for source rehearsal; target execution uses `dbx_sql.py` |
| `trino/docker-compose.yml` | Trino, Hive volume, and Postgres services | L | Retain as the source rehearsal environment |

## Decisions and risks

`COUNT(DISTINCT)` replaces `approx_distinct`. For these group sizes, the
exact count makes parity provable instead of carrying HLL estimation error.
`percentile_approx` replaces `approx_percentile`; both are approximate, so
their median values can differ even when the input rows match.
The report 22 columns remain unchanged as requested.

The source `CHAR(4)` region values are preserved, including `NORT` and `SOUT`.
The source mart excludes cancelled orders before aggregation, and the target
does the same. The source customer LTV table has 150 rows because the
deterministic seed gives one region only cancelled orders.

The highest SQL risk is report 22 because map explosion and approximate
percentiles combine dialect and numeric behavior. The next risk is the
customer LTV array aggregation because ordering and null handling must stay
stable. The load boundary is also material: CSV quoting must preserve JSON
maps and arrays before `from_json` parses them.

The run loaded all nine snapshot tables, backfilled core and ops, rebuilt both
marts, and executed all three reports. Evidence files under
`docs/evidence/run-1/` contain the source CSV outputs and target TSV outputs.
