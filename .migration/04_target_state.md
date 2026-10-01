# Target state — order analytics, Redshift → Databricks

Plan step `workspace-setup`, approved plan revision 24. Every surface cites a reference
implementation (a real file) or a standards document; a surface without a target is N/A with
its reason. Workers convert *to* this table; they never change it (plan decision only).

| Surface | Target | Reference implementation / standard | Legacy input |
|---|---|---|---|
| CORE | Delta tables in Unity Catalog `migration_demo.core` (`customers`, `orders`, `order_items`), legacy table and column names preserved; `DISTKEY`/`SORTKEY`/`IDENTITY` dropped, `GENERATED ALWAYS AS IDENTITY` where a surrogate key is needed | official plugin skill `databricks-unity-catalog/SKILL.md` (object model, grants) and `databricks-dbsql/SKILL.md` (DDL) | `sql/ddl/01_schemas.sql`, `sql/ddl/02_core_tables.sql` |
| SQL | Databricks SQL on warehouse `565cd2fd713738c4` (Serverless Starter Warehouse). Dialect: Redshift `TRUNC` on a timestamp → `DATE`, `DECODE` → `CASE`, `GETDATE` → `current_timestamp`, `DATEDIFF day,a,b` → `datediff b,a`, blank-padded `CHAR` compares → `rtrim` (canonicalization rules in `03_recon_tolerances.json`) | official plugin skill `databricks-dbsql/SKILL.md` and its `references/`; probe `SELECT 1` on the warehouse WORKS (probe table in the ticket PR) | `sql/etl/10_build_daily_revenue.sql`, `sql/etl/11_build_customer_ltv.sql` |
| PIPELINE (Lakeflow Spark Declarative Pipelines / DLT) | N/A | The two mart builds are full-rebuild CTAS over two small core tables with no streaming or CDC input; a declarative pipeline adds nothing a SQL job task cannot do. Re-open only by plan decision. | — |
| ORCHESTRATION | Lakeflow Jobs defined in a Databricks Asset Bundle, bundle target `migration`, SQL tasks on warehouse `565cd2fd713738c4` in the legacy order 10 then 11, schedule PAUSED until cutover; replaces the stored-procedure wrapper the customer scheduler calls nightly | official plugin skills `databricks-jobs/SKILL.md` (SQL task, `sql_task.warehouse_id`) and `databricks-dabs/SKILL.md` (bundle layout, `targets:`); factory delta in `dbx-migration-factory/skills/target-routing/SKILL.md` (PAUSED schedules, never prod from a child) | `sql/etl/12_sp_refresh_marts.sql` |
| CONSUMER | Executive-dashboard queries as Databricks SQL in `sql/reports`, reading `migration_demo.mart.*`; `DATEADD day,-30,TRUNC GETDATE` → `date_sub current_date, 30` | reference implementation: the two report queries themselves, converted in place; `databricks-dbsql/SKILL.md` for dialect | `sql/reports/20_region_topline.sql`, `sql/reports/21_channel_trend.sql` |
| LAKEBASE | N/A | The estate is analytical only, no OLTP track; `allowed_targets.json` carries no `lakebase_projects` or `lakebase_branches`. | — |
| ML-SCORING | N/A | No models, scoring jobs or feature tables exist in the legacy estate; `sql/` is DDL, ETL and reports only. | — |
| DATA / DEPENDENCY | Live legacy read through Lakehouse Federation: connection `redshift_demo` → foreign catalog `redshift_src` (`redshift_src.core.*`, `redshift_src.mart.*`), read-only, legacy-query concurrency cap 1 (`03_recon_tolerances.json`); initial load of `migration_demo.core` by single-shot CTAS from the foreign catalog (small-and-static load class); reconciliation with `dbx-recon --family databricks` through the same catalog | `dbx-migration-factory/skills/data-reconciliation/SKILL.md`, sections "Live mode prerequisites" and "Load posture"; probe results in the ticket PR (federated read currently BLOCKED: the service principal lacks `USE CATALOG` on `redshift_src` and `migration_demo`) | Redshift Serverless `demo-wg` / database `demo`, principal `devin-redshift-demo` |

## Fixed facts the workers inherit

- Target catalog `migration_demo`; schemas `core` and `mart` mirror the legacy schemas.
- Warehouse `565cd2fd713738c4` for every SQL task, probe and recon query.
- Identity: the migration service principal recorded in `09_capabilities.json`; OAuth M2M, no PATs.
- Legacy is read-only in every phase. `devin-redshift-demo` can DROP but not CREATE Redshift
  `mart` tables, so `sql/etl/*` is never executed against Redshift by any session: it is
  conversion input only. Mart tables are rebuilt on Databricks from `migration_demo.core`.
- Secrets by name: `DATABRICKS_DEMO_HOST`; `AWS_DEMO_ACCESS_KEY_ID` and `AWS_DEMO_SECRET_ACCESS_KEY`
  (legacy, read-only IAM user `devin-redshift-demo`). `REDSHIFT_DEMO_ADMIN_PASSWORD` is never used
  by a migration session.
