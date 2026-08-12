---
name: testing-recon-suite
description: How to run the Redshift→Databricks migration recon suite end-to-end (ETL rebuild, recon queries, report parity) for this repo.
---

# Redshift→Databricks recon testing

## Access
- Databricks: Statement Execution API on SQL warehouse `565cd2fd713738c4` using `$DATABRICKS_DEMO_HOST` + `$DATABRICKS_DEMO_TOKEN`. Do NOT create new warehouses. Helper: `~/dbx_sql.py <file-or-sql>` (splits on semicolons — beware semicolons inside comments; the converted ETL files are single-statement so pass whole files).
- Redshift (read/most ops): Data API via boto3, region `us-east-1`, workgroup `demo-wg`, db `demo`, creds `$AWS_DEMO_ACCESS_KEY_ID`/`$AWS_DEMO_SECRET_ACCESS_KEY`. Helper: `~/rs_sql.py` (single statement, crashes on DDL with no result set — use a multi-statement runner that checks `HasResultSet`).
- The `devin-redshift-demo` IAM user CANNOT `CREATE TABLE` in schema `mart` (it CAN drop!). Running `sql/etl/*.sql` on Redshift as that user drops the mart table then fails on CREATE, destroying the legacy mart. If you must rebuild Redshift marts, connect as `demoadmin` with `REDSHIFT_DEMO_ADMIN_PASSWORD` via `redshift_connector` (`pip3 install redshift_connector`) to host `demo-wg.599083837640.us-east-1.redshift-serverless.amazonaws.com:5439`, db `demo`. After rebuilding, run `GRANT SELECT ON ALL TABLES IN SCHEMA mart TO PUBLIC` so federation/recon can read them.

## Procedure
1. Recon SQL lives on branch `demo-ops`: `git show origin/demo-ops:recon/0{1,2,3}_*.sql`.
2. `redshift_src` is a live federation catalog into Redshift. `scripts/drift_loader.py` (demo-ops) may have injected fresh orders, making `migration_demo.core.orders` stale — recon then shows count/diff mismatches that are NOT conversion bugs.
3. If drift is present: resync `CREATE OR REPLACE TABLE migration_demo.core.orders AS SELECT * FROM redshift_src.core.orders`, rebuild Redshift marts as demoadmin (legacy `sql/etl/10`, `11`), rebuild Databricks marts (`databricks/etl/10`, `11`), then re-run recon.
4. Green = counts equal for all 5 tables, `avg_mismatch_rows = 0`, all four EXCEPT diffs = 0.
5. Report parity: run `sql/reports/20,21` on Redshift vs `databricks/reports/20,21` on Databricks; strip ` 00:00:00` from Redshift dates before diffing (Redshift TRUNC yields timestamp-formatted dates in Data API output).

## Devin Secrets Needed
- DATABRICKS_DEMO_HOST, DATABRICKS_DEMO_TOKEN
- AWS_DEMO_ACCESS_KEY_ID, AWS_DEMO_SECRET_ACCESS_KEY
- REDSHIFT_DEMO_ADMIN_PASSWORD (only for rebuilding Redshift marts)

## Misc
- The default `python3` on the box may resolve to an unrelated venv; konsole shells may lack boto3 — use the venv python that has boto3 or `pip3 install boto3 redshift_connector`.
