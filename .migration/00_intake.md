# DBX Migration Intake (run 2)

Stops route to this session only. The cutover principal is none (demo, STOP E
not authorized).

| Question | Answer | Why the repo cannot discover it |
|---|---|---|
| 1. Source system and secret names | **FACT** — local Docker Trino 483 (`lake` Hive/Parquet and `ops` PostgreSQL JDBC); Databricks uses `DATABRICKS_DEMO_HOST` and `DATABRICKS_DEMO_TOKEN`; live PostgreSQL source DSN is named `TRINO_OPS_DSN`. | Source ownership and secret values are outside the repo. |
| 2. Pipeline order and scope | **DISCOVERED** — wave 0 is `ops_tables`; wave 1 is `marts` and `report_22`; writes are limited to `trino_migration_demo.ops` and `trino_migration_demo.mart`. | Priority and sequencing are human decisions. |
| 3. Stops and cutover principal | **FACT** — stops route to this session only; cutover principal: none (demo, STOP E not authorized). | Slack or Teams routing and the human cutover principal are outside the repo. |
| 4. Correctness contract | **PROPOSED** — exact match, zero numeric and aggregate tolerance, all rows, `decimal_round` at two places only for recomputed averages/ratios; marts are DEGRADED snapshot evidence. | The business acceptance contract is not discoverable from source files. |
