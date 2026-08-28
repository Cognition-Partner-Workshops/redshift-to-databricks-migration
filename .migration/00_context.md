# 00 — Engagement Context

- Engagement: test run of the DBX Migration Factory on the Redshift estate in this repo.
- Run: `migration-run-6` (integration branch). `main` = pristine pre-migration estate; never merge migration PRs into `main`.
- Source: Amazon Redshift Serverless 1.0.417950, workgroup `demo-wg`, db `demo`, us-east-1.
  Access: Redshift Data API with secrets `AWS_DEMO_ACCESS_KEY_ID`/`AWS_DEMO_SECRET_ACCESS_KEY`
  (IAM user `devin-redshift-demo`); admin path `demoadmin` via `REDSHIFT_DEMO_ADMIN_PASSWORD` (psql/redshift_connector) for mart rebuilds only.
- Target: Databricks demo workspace (`DATABRICKS_DEMO_HOST`/`DATABRICKS_DEMO_TOKEN`, PAT auth),
  SQL warehouse `565cd2fd713738c4` (do not create warehouses), UC catalog `migration_demo`,
  federation catalog `redshift_src` (connection `redshift_demo`, read-only).
- Target state: `docs/migration/Redshift_target_state.md` (CORE + SQL/PIPELINE/ORCHESTRATION/CONSUMER/DATA profiles; ML-SCORING N/A). Knowledge note to be updated after STOP A.
- Estate census (probed 2026-08-28): schemas `core` (customers, orders, order_items), `mart`
  (daily_revenue, customer_ltv); 7 SQL assets in `sql/` (2 DDL, 3 ETL incl. 1 stored procedure, 2 reports).
- Standalone session, no parent orchestration.
- Notification contract: none named — all stops surface in-session only.
