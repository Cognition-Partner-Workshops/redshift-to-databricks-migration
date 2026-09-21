# Order Analytics on Trino

This estate runs order analytics on Trino. The `lake` catalog uses the data-lake
volume with Hive metadata and Parquet tables, while the `ops` catalog reads
operational customer data from Postgres. The nightly mart rebuild uses a full
refresh, and the report queries feed the executive dashboard.

## Run

From this directory:

```sh
make all
make down
```

## Layout

- `docker-compose.yml` — Trino and the operational Postgres service
- `etc/` — Trino configuration and catalog definitions
- `ops-db/init.sql` — operational customer and tag data
- `sql/ddl/` — schemas and core table definitions
- `sql/seed/` — deterministic order and item loads
- `sql/etl/` — nightly mart rebuilds
- `sql/reports/` — executive dashboard queries
