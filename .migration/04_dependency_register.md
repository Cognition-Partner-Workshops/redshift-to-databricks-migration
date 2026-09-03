# 04 — Dependency Register

Taxonomy: D1 schema/DDL · D2 data availability · D3 upstream ingestion · D4 downstream consumers ·
D5 dialect/function semantics · D6 orchestration/schedule · D7 security/PII · D8 performance ·
D9 tooling · D10 access/environment prerequisite.

| ID | Type | Description | Status | Owner | Opened |
|---|---|---|---|---|---|
| DEP-001 | D4 | Query history carries no consumer evidence: `sys_query_history` (via `demoadmin`) = 1,193 rows / 3 users / 7-day window, all demo or migration principals; no BI or loader identity. D4 sweep must use the user-declared landscape (README: exec dashboard; ingestion pipeline unnamed). Request: user names the BI tool and loader | OPEN (fired at intake 2026-09-03; accepted-risk default if unanswered) | user | 2026-09-03 |
| DEP-002 | D10 | `svv_table_info` denied to assessment principal `IAM:devin-redshift-demo`; dist/sort key detail read via DDL in `sql/ddl/` plus `pg_class.reldiststyle`, and via `demoadmin` when needed. No request fired — mitigated | MITIGATED | Devin | 2026-09-03 |
| DEP-003 | D3/D10 | `pg_auto_copy.copy_job_detail` denied to both `IAM:devin-redshift-demo` and `demoadmin` — cannot confirm whether the Redshift loader is an auto-copy job. Request: `GRANT USAGE ON SCHEMA pg_auto_copy` to the assessment principal, or the loader's name from the user | OPEN (fired at intake 2026-09-03) | user | 2026-09-03 |
| DEP-004 | D10 | Databricks auth is a human-user PAT (`DATABRICKS_DEMO_TOKEN`), not the migration service principal prescribed by the access model. Acceptable for this demo estate; attribution in query history is to the PAT identity | OPEN (accepted risk, demo estate) | user | 2026-09-03 |
| DEP-005 | D2 | Backfill drift: `migration_demo.core.orders` = 63,997 vs `redshift_src.core.orders` = 64,397 (400 new legacy rows). Not a setup blocker; resync is part of wave 0 / recon drift protocol | OPEN | Devin | 2026-09-03 |
| DEP-006 | D6 | `mart.sp_refresh_marts` is not deployed on the live warehouse (`pg_proc_info` empty); the nightly schedule's real driver is unknown. Treat the procedure source as the schedule spec; scheduler identity requested from user | OPEN | user | 2026-09-03 |

History (run-6, 2026-08-28): federation connection `redshift_demo` had a stale credential, refreshed and verified then; verified again 2026-09-03 with no repair needed.
