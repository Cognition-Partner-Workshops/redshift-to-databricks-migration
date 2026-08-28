# 07 — Access Checklist

Live probes, 2026-08-28 (this session):

| Check | Result | Evidence |
|---|---|---|
| Redshift metadata read (Data API, IAM `devin-redshift-demo`) | WORKS | `SELECT version()` → Redshift 1.0.417950; `information_schema.tables` census of `core`/`mart` (5 tables) |
| Redshift query history | WORKS (sparse) | `SELECT count(*) FROM sys_query_history` → 8 rows; weak D4 evidence (DEP-001) |
| Redshift admin path (`demoadmin`, psql :5439) | WORKS | `SELECT 1` via psql with `REDSHIFT_DEMO_ADMIN_PASSWORD` |
| Databricks warehouse `565cd2fd713738c4` | WORKS | `SELECT current_catalog(), current_user()` succeeded |
| Federation read (`redshift_src`) | WORKS (repaired) | Initially FAILED (BAD_REQUEST — stale connection credential); credential refreshed via UC API, then `SELECT count(*) FROM redshift_src.core.orders` → 63,197 |
| Target catalog write (`migration_demo`) | WORKS | CREATE/DROP probe table in `migration_demo.default` |
| Backfill freshness | IN SYNC | `migration_demo.core.orders` = `redshift_src.core.orders` = 63,197 rows |

No BLOCKED items → no open D10 requests.

## Access model (for security review)

| Tier | Principal / secret | Scope | Used for |
|---|---|---|---|
| Assessment (read-only) | IAM `devin-redshift-demo` (`AWS_DEMO_*` secrets), Redshift Data API | USAGE/SELECT on `core`, `mart`; system catalogs; query history | Census, lineage, recon reads. CANNOT create tables in `mart` (but CAN drop — never run `sql/etl/*` on Redshift under this tier) |
| Migration (sandbox write + legacy read) | Databricks PAT (`DATABRICKS_DEMO_*`), UC catalog `migration_demo`; federation `redshift_src` read-only; `demoadmin` (`REDSHIFT_DEMO_ADMIN_PASSWORD`) only for legacy mart rebuilds during recon resync | Write to `migration_demo` only; no DDL/DML on legacy except sanctioned mart rebuild + `GRANT SELECT ... TO PUBLIC`; no grants on production catalogs | Conversion, backfill, recon |
| Cutover | Customer-held; not provisioned to Devin | Production repoint | Used once at STOP E |

Attribution: all Databricks statements run as the PAT identity on warehouse
`565cd2fd713738c4` (query history); Redshift Data API statements attributable to
IAM user `devin-redshift-demo` in `sys_query_history`.
