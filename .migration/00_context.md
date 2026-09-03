# 00 — Engagement Context

Provenance legend: **FACT** (stated by user / intake template), **DISCOVERED** (probed live this session), **PROPOSED** (default; confirmable at STOP A).

## Intake (front door: SQL Warehouse Estate, 2026-09-03)

- Intake template: none attached or committed (`00_intake_template.md` absent) — every row below is DISCOVERED or PROPOSED.
- Family: SQL warehouse estate. Engine: **Amazon Redshift Serverless**, version `Redshift 1.0.416217` (DISCOVERED, `SELECT version()`), workgroup `demo-wg`, database `demo`, region `us-east-1`. Endpoint `demo-wg.599083837640.us-east-1.redshift-serverless.amazonaws.com:5439` (DISCOVERED from the existing federation connection).
- Repo: `Cognition-Partner-Workshops/redshift-to-databricks-migration` = SOURCE (legacy SQL under `sql/`), TARGET (converted code under `databricks/`, per prior runs) and DOCS (`docs/migration/`, `.migration/`). `main` = pristine pre-migration estate; never merge migration PRs into `main` (FACT, repo knowledge). Integration branch for this run: `migration-run-9`, fresh from `main` (PROPOSED — reply "use migration-run-N" to change).
- Dialect skill attached: `redshift-sql` (plugin `dbx-migration-plugin` v0.1.0). Also loaded: `lakehouse-federation`, `databricks-auth-cli`.
- `stop_mode`: **soft** (PROPOSED default; reply "stop_mode hard" or "make STOP C hard" to change). STOP E always hard.
- Notification contract: none named — stops surface in this web session only (PROPOSED).
- Interaction contract: one decision per stop, recommended default + exact approving reply, artifacts attached; 2-4 sentences per message; events = STOPs A/B/C/E, wave close (D), halts only.

## Access probed at intake (2026-09-03, live)

| Check | Principal | Result | Evidence |
|---|---|---|---|
| Redshift metadata read | `IAM:devin-redshift-demo` via Data API (`AWS_DEMO_ACCESS_KEY_ID` / `AWS_DEMO_SECRET_ACCESS_KEY`) | WORKS | `information_schema.tables`: `core` 3 base tables, `mart` 2 base tables; `pg_class.reldiststyle` readable (customers/orders/order_items/customer_ltv = KEY, daily_revenue = ALL); `svv_relation_privileges` 542 rows |
| Redshift `svv_table_info` (dist/sort key detail) | `IAM:devin-redshift-demo` | BLOCKED (permission denied) → D10 | Works via `demoadmin` (5 rows for core+mart); DDL in `sql/ddl/` is the primary physical-design source |
| Redshift query history (`sys_query_history`) | `IAM:devin-redshift-demo` | PARTIAL — sees only its own 213 queries | Non-superuser visibility limited to own statements |
| Redshift query history, full | `demoadmin` (`REDSHIFT_DEMO_ADMIN_PASSWORD`, psql :5439, read-only use) | WORKS but **weak D4 evidence** | 1,193 rows, 3 users (`demoadmin` 972, `IAM:devin-redshift-demo` 213, `IAM:Devin-PartnerWorkshops-Demo` 9), window 2026-08-28 → 2026-09-03 (~7-day retention). Every user is a demo/migration operator; **no BI or ingestion principal appears** → consumer detection from query history is not available for this estate |
| Redshift stored procedures deployed | `IAM:devin-redshift-demo` | DISCOVERED: none | `pg_proc_info` for `core`/`mart` is empty; `mart.sp_refresh_marts` exists only as source in `sql/etl/12_sp_refresh_marts.sql` (not deployed to the live warehouse) |
| Redshift `pg_auto_copy` (ingestion jobs) | both principals | BLOCKED (permission denied for schema) → D10 | View `pg_auto_copy.copy_job_detail` exists; cannot read to confirm the loader |
| Databricks warehouse `565cd2fd713738c4` | PAT `DATABRICKS_DEMO_HOST` / `DATABRICKS_DEMO_TOKEN` (human-user PAT, not a service principal — see D10 below) | WORKS | `SELECT current_user(), current_metastore()` |
| Lakehouse Federation to Redshift | connection `redshift_demo` (REDSHIFT, read_only=true), foreign catalog `redshift_src` | WORKS — **federation is already approved and live** | `SELECT count(*) FROM redshift_src.core.orders` = 64,397 |
| Target catalog | UC catalog `migration_demo` | EXISTS (write probe deferred to `!dbx_migration_setup`) | `SHOW CATALOGS` |

D10 items registered for the setup phase: (1) `svv_table_info` read for the assessment principal — mitigated by DDL + admin path; (2) `pg_auto_copy` read to identify the loader — request `GRANT USAGE ON SCHEMA pg_auto_copy` or the loader's name from the user; (3) query history carries no consumer evidence — the D4 sweep must use the user-declared ingestion/BI landscape instead; (4) Databricks auth is a human PAT, not the migration service principal the access model prescribes — acceptable for this demo estate, flagged.

## Landscape (seeds for D3/D4 sweeps)

- Ingestion: `core.*` are append-only; orders "land continuously from the ingestion pipeline" (README). Loader identity unknown (`pg_auto_copy` blocked; history shows only multi-row `INSERT INTO core.orders` from demo principals). PROPOSED: treat the loader as an external append-only writer that keeps writing to Redshift through coexistence; federation carries its output to Databricks. Reply with the loader's name/tool to replace this.
- Consumers: `sql/reports/20_*`, `21_*` are "consumed by the exec dashboard" (README); BI tool unnamed. PROPOSED: one BI consumer (exec dashboard), re-point at cutover. Reply with the BI tool and any extracts/APIs to widen the D4 sweep.
- Scheduling: nightly full-refresh marts (`DROP + CTAS`) run in numeric order `10_* → 11_*` by an unnamed scheduler, wrapped by `mart.sp_refresh_marts` (source only). Scheduler identity unknown (PROPOSED: treat as external cron; target = Databricks Workflows).

## Family defaults (SQL warehouse chain)

- Unit = view / procedure / scheduled query / load script; census key `schema.object`.
- Lineage extraction = catalog metadata (`pg_*`, `svv_*`) + view dependency graphs + repo SQL parse; query history is available (admin path) but carries no consumer signal here.
- SQL profile is the dominant surface (ETL CTAS scripts, 1 plpgsql procedure, 2 report queries). ML-SCORING N/A (no ML jobs). PIPELINE/ORCHESTRATION/CONSUMER profiles thin.
- Physical design translation is a named dictionary concern: DISTKEY/SORTKEY/DISTSTYLE ALL → liquid clustering (or partitioning per target state); performance-parity expectation recorded, keys never carried as comments.
- Coexistence and recon: **federation-first** (`redshift_src`, read-only). Recon mode LIVE.
- Known dialect traps to pre-seed the dictionary: integer `AVG` truncation, `TRUNC(timestamp)` → date, `GETDATE()`, `DECODE`, `CHAR(n)` blank-padding compares, `DECIMAL` arithmetic scale, `DATEADD/DATEDIFF` argument order.

## Target & tooling facts (carried from repo knowledge)

- Databricks SQL via Statement Execution API on warehouse `565cd2fd713738c4` (do not create warehouses); UC catalog `migration_demo`; federation `redshift_demo` / `redshift_src`.
- Redshift admin path (`demoadmin`) is for legacy mart rebuilds during recon resync only; the assessment principal can DROP but not CREATE in `mart` — never run `sql/etl/*` on Redshift as that principal.
- Helper scripts on the box: `~/rs_sql.py` (Data API), `~/dbx_sql.py` (Statement Execution API); `pip3 install boto3 redshift_connector` was required this session.

## Setup (`!dbx_migration_setup`, 2026-09-03)

- Designated write area: UC catalog `migration_demo` (schemas `core`, `mart`, `default`) on warehouse `565cd2fd713738c4`; repo paths `databricks/`, `scripts/`, `docs/migration/`; `.migration/` orchestrator-only. Allow-list: `.migration/allowed_targets.json`. Write probe: `CREATE TABLE migration_demo.default._access_probe_20260903` + `DROP TABLE` = OK (DISCOVERED).
- Target catalog already holds 5 tables from prior runs; `migration_demo.core.orders` = 63,997 vs live 64,397 → DEP-005 drift, resync in wave 0 (DISCOVERED).
- Target state: `docs/migration/Redshift_target_state.md` v2 (refreshed from run-6 v1; all PROPOSED rows re-queued for STOP A). Tolerances: `.migration/03_recon_tolerances.md` v2 (PROPOSED). Access: `.migration/07_access_checklist.md`. Dependencies: `.migration/04_dependency_register.md` (DEP-001…006).
- Access model: Databricks via human PAT rather than a migration service principal (DEP-004, accepted-risk default for the demo estate); Redshift assessment principal read-only; `demoadmin` read-only except the documented mart-rebuild path.
- Interaction contract: stops surface in this web session only; `stop_mode` soft; one message per STOP / wave close / halt.
- Prior-run assets (`origin/devin/1786578025-sql-conversion-recon-run4` `databricks/**`, `docs/ASSESSMENT.md` on run-4/5) are reference material only; run-9 re-derives every unit through the chain and recon gating.
