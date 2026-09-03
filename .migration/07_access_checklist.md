# 07 — Access Checklist (verified 2026-09-03)

Access model (target): migration service principal for Databricks; read-only assessment principal for Redshift;
`demoadmin` used read-only except the documented mart-rebuild path in the recon procedure. Actual identities below.

| # | Access | Identity / secret (names only) | Probe | Result |
|---|---|---|---|---|
| 1 | Redshift catalog metadata (`information_schema`, `pg_class`, `svv_relation_privileges`) | `IAM:devin-redshift-demo` via Data API — `AWS_DEMO_ACCESS_KEY_ID` / `AWS_DEMO_SECRET_ACCESS_KEY` | `SELECT version()`; `information_schema.tables` | WORKS (5 base tables: core 3, mart 2) |
| 2 | Redshift `svv_table_info` | `IAM:devin-redshift-demo` | select | DENIED → DEP-002 (mitigated via DDL + `demoadmin`) |
| 3 | Redshift query history (full) | `demoadmin` — `REDSHIFT_DEMO_ADMIN_PASSWORD` (psql :5439, read-only) | `sys_query_history` | WORKS — 1,193 rows / 3 users / ~7 days; no consumer signal → DEP-001 |
| 4 | Redshift `pg_auto_copy` | both | select `copy_job_detail` | DENIED → DEP-003 |
| 5 | Redshift data reads (recon baseline) | via federation `redshift_src` | `count(*) redshift_src.core.orders` | WORKS — 64,397 |
| 6 | Databricks SQL warehouse `565cd2fd713738c4` | PAT — `DATABRICKS_DEMO_HOST` / `DATABRICKS_DEMO_TOKEN` (human user; DEP-004) | `SELECT current_user(), current_metastore()` | WORKS |
| 7 | UC connection / foreign catalog | `redshift_demo` (REDSHIFT, read_only=true) / `redshift_src` | `SHOW CONNECTIONS`, `SHOW CATALOGS`, federated count | WORKS — no credential repair needed this run |
| 8 | Target catalog write | `migration_demo` | `CREATE TABLE migration_demo.default._access_probe_20260903 (x INT)`; `DROP TABLE` | WORKS (probe table created and dropped) |
| 9 | Target catalog state | `migration_demo.core.*`, `migration_demo.mart.*` | `SHOW TABLES` | 5 tables present from prior runs; `core.orders` 63,997 (stale by 400 → DEP-005) |
| 10 | Repo write | `Cognition-Partner-Workshops/redshift-to-databricks-migration` | branch push / PR | to be exercised by the setup PR |
| 11 | Cutover principal (customer-held) | not provisioned to Devin | — | N/A until STOP E; Devin never holds it |

Not exercised this run: Databricks Workflows job creation (deferred to the `sp_refresh_marts` wave), Asset Bundles (out of scope).
