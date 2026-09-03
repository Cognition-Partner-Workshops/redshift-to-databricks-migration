# Redshift Estate — Target State (Databricks)

Engagement: Redshift Serverless → Databricks migration, repo
`Cognition-Partner-Workshops/redshift-to-databricks-migration`.
Every field is marked **FACT** (cited) or **PROPOSED**. Surfaces not present in this estate
are marked **N/A** with a reason.

Version: v2 (2026-09-03, run `migration-run-9`). v1 was confirmed at STOP A on 2026-08-28
(run `migration-run-6`); v2 refreshes every probed fact and re-queues all PROPOSED fields
for this run's STOP A — a prior approval never carries over.

Sources:
- S1 — Reference implementation: converted Databricks ETL/reports on prior run branches
  (`origin/devin/1786578025-sql-conversion-recon-run4`, files `databricks/etl/*.sql`,
  `databricks/reports/*.sql`). Strongest evidence: merged/accepted converted code.
- S2 — Prior assessment: `docs/ASSESSMENT.md` on `origin/migration-run-4` / `migration-run-5`.
- S3 — Repo skill: `.agents/skills/testing-recon-suite/SKILL.md` (recon procedure, access).
- S4 — Environment blueprint knowledge (workspace/warehouse/federation facts, demo layout).
- S5 — Live probes this session (Redshift Data API + `demoadmin` psql, Databricks Statement
  Execution API), 2026-09-03.
- S6 — Front-door intake: `.migration/00_context.md` (engine pin, access probes, family defaults).
- S7 — Prior setup artifacts (run-6): `origin/devin/1787954987-migration-setup` (`.migration/*`,
  this document's v1).

## CORE (applies to everything)

| Field | Value | Status |
|---|---|---|
| Source engine | Amazon Redshift Serverless, version `1.0.416217` (`SELECT version()` 2026-09-03; v1 recorded 1.0.417950 on 2026-08-28 — serverless patch level floats), workgroup `demo-wg`, db `demo`, us-east-1 | FACT (S5, S6) |
| Target platform | Databricks on the demo workspace (`$DATABRICKS_DEMO_HOST`), SQL warehouse `565cd2fd713738c4` ("Serverless Starter Warehouse"); do NOT create new warehouses | FACT (S3, S4) |
| Unity Catalog layout | Catalog `migration_demo`; schema per Redshift schema: `core` (landing), `mart` (BI aggregates). Federation catalog `redshift_src` mirrors live Redshift via connection `redshift_demo` | FACT (S4, S5: `SHOW SCHEMAS IN migration_demo` → core, mart) |
| Table format | Delta (managed tables in `migration_demo`); full-refresh marts use `CREATE OR REPLACE TABLE ... AS SELECT` mirroring legacy Drop+CTAS | FACT (S1) |
| Naming | Keep legacy schema/table/column names 1:1 (`core.orders`, `mart.daily_revenue`, ...) | FACT (S1, S5) |
| Code language policy | Databricks SQL for all ETL/reports; Python only for tooling (recon harness, loaders) | FACT (S1, S3) |
| Repo layout | Single repo, three roles in one: SOURCE = `sql/` (legacy Redshift, read-only during migration), TARGET = `databricks/` (converted code) + `scripts/` (tooling), DOCS = `docs/` + `.migration/` | FACT (S1, S2 layout) |
| Branch/PR model | `main` is the pristine pre-migration estate — never merge migration PRs into `main`. Each run uses a `migration-run-N` integration branch; unit branches PR into it. This engagement: `migration-run-9` (fresh from `main`) | FACT (S4) / PROPOSED (run-9) |
| CI gates | No repo CI configured; the PR-evidence contract (recon output attached to every unit PR) is the gate | FACT (repo has no workflows) / PROPOSED as the standing gate |
| Deployment | SQL executed via Statement Execution API on warehouse `565cd2fd713738c4`; no Asset Bundles in use | FACT (S3) — Asset Bundles PROPOSED as out of scope for this run |
| Secrets | Referenced by Devin secret name only (`AWS_DEMO_*`, `DATABRICKS_DEMO_*`, `REDSHIFT_DEMO_ADMIN_PASSWORD`); never committed | FACT (S3) |
| Forbidden patterns | Running `sql/etl/*` on Redshift as `devin-redshift-demo` (drops mart, cannot recreate — destroys legacy mart); creating new warehouses; merging into `main` | FACT (S3, S4) |

## SQL profile (views / procedures / report queries)

| Field | Value | Status |
|---|---|---|
| Dialect policy | Redshift SQL → Databricks SQL per the established translation dictionary: `TRUNC(ts)`→`CAST(... AS DATE)`, `GETDATE()`→`current_date()/current_timestamp()`, `DECODE`→`CASE`, `DATEADD/DATEDIFF` arg-order fixes, `IDENTITY(1,1)`→`GENERATED ALWAYS AS IDENTITY` | FACT (S1, S2) |
| CHAR semantics | Redshift blank-padded `CHAR(n)` comparisons → `RTRIM()` on migrated STRING columns; comparison literals unpadded | FACT (S1) |
| Numeric semantics | Redshift DECIMAL division truncates toward zero at output scale; Databricks rounds. Reproduce truncation explicitly: `SIGN(x)*FLOOR(ABS(x), scale)` for AVG/division outputs | FACT (S1) |
| Materialization policy | Marts = full-refresh Delta tables via `CREATE OR REPLACE TABLE AS` (mirrors legacy Drop+CTAS); reports stay queries | FACT (S1) |
| Physical design translation | `DISTSTYLE`/`DISTKEY`/`SORTKEY` dropped on Delta; liquid clustering / `OPTIMIZE` optional and not applied at current data volumes | FACT (S1) / PROPOSED (no clustering this run) |
| Stored procedures | Redshift PL/pgSQL (`sp_refresh_marts`) is not portable; re-platform as an ordered job/workflow running mart builds 10 → 11. Note: the procedure is **not deployed** on the live warehouse (`pg_proc_info` empty for `core`/`mart`); it exists only as source `sql/etl/12_sp_refresh_marts.sql` | FACT (S1: `databricks/etl/12_refresh_marts_job.sql`, S2, S5) |
| Report-output contract | Report parity vs legacy: identical rows after stripping ` 00:00:00` from Redshift Data API date rendering | FACT (S3) |

## PIPELINE profile (ETL)

| Field | Value | Status |
|---|---|---|
| Target runtime | SQL statements on warehouse `565cd2fd713738c4` (script/job driven); no DLT | FACT (S1, S3) |
| Layering | Two-layer: `core` (raw landing, append-only) → `mart` (aggregates). No medallion rename — keep legacy layer names | FACT (S5 schema census) / PROPOSED (no bronze/silver/gold re-layering) |
| Load pattern | `core` tables backfilled from `redshift_src` federation (`CREATE OR REPLACE TABLE ... AS SELECT * FROM redshift_src...`); marts full-refresh | FACT (S3) |
| Restart/idempotency | Full-refresh CTAS is idempotent; safe to rerun any step. Numeric order execution (10 before 11) must be preserved | FACT (S1, repo convention) |
| Error handling | Job-level failure surfaces via the nightly recon job's `notify_devin` webhook task | FACT (S4) |
| Drift handling | `scripts/drift_loader.py` (demo-ops) may inject fresh Redshift orders; recon mismatch from drift is NOT a conversion bug — resync core from federation, rebuild both marts, re-run recon | FACT (S3) |

## ORCHESTRATION profile

| Field | Value | Status |
|---|---|---|
| Scheduler | Databricks Workflows. Existing job `redshift-migration-nightly-recon` (id 220238957207364), 06:00 UTC nightly on warehouse `565cd2fd713738c4` | FACT (S4) |
| Legacy schedule mapping | Legacy "nightly ETL" (sp_refresh_marts) → Databricks job running `databricks/etl/10,11` in order; replaces the procedure | FACT (S1, S2) — job creation itself PROPOSED for a later wave |
| Alerting | Recon-failure → Devin automation webhook ("Redshift migration recon failure — auto-remediate") | FACT (S4) |
| Backfill procedure | Re-run core resync + mart rebuilds (idempotent CTAS) | FACT (S3) |

## CONSUMER profile (BI / extracts)

| Field | Value | Status |
|---|---|---|
| Known consumers | Two BI report queries (`sql/reports/20_region_topline.sql`, `21_channel_trend.sql`) — executive/regional dashboards | FACT (S2) |
| Re-point vs rebuild | Rebuild: dialect-converted copies under `databricks/reports/`, parity-verified; no external BI tool connections known | FACT (S1) |
| Untracked consumers | `sys_query_history` (full view via `demoadmin`, read-only): 1,193 rows, 3 users, 2026-08-28 → 2026-09-03 (~7-day retention) — every user is a demo/migration principal (`demoadmin`, `IAM:devin-redshift-demo`, `IAM:Devin-PartnerWorkshops-Demo`); **no BI or loader traffic**, so query history cannot detect consumers here. D4 sweep relies on the user-declared landscape (README: one exec dashboard; unnamed ingestion pipeline). Registered as DEP-001 | FACT (S5, S6) |
| Cutover SLA | N/A for demo — no external consumers identified | PROPOSED |

## ML-SCORING profile

**N/A** — the estate contains no model training or scoring workloads (full census of
`core`/`mart` schemas and all repo SQL: ETL + BI reports only). (FACT, S2/S5)

## DATA / DEPENDENCY profile

| Field | Value | Status |
|---|---|---|
| Coexistence mechanism | Lakehouse Federation (connection `redshift_demo`, read-only, foreign catalog `redshift_src`) — the live read bridge and recon baseline | FACT (S4, S5: repaired and verified this session) |
| Dual-write | None — one-directional migration; Redshift remains source of truth until cutover | FACT (S3 workflow) / PROPOSED |
| PII/masking | No PII rules defined; demo data is synthetic (seeded by `scripts/seed_redshift.py`) | FACT (S4 demo-ops) — no masking PROPOSED |
| Sample-data fallback | Not needed — full live access exists (recon mode LIVE) | FACT (S5) |
| Decommission criteria | All 5 tables recon-green, report parity green, nightly recon job green on Databricks-only lineage; Redshift decommission is out of scope for this test run | PROPOSED |

## Cross-profile reconciliation
- Numeric truncation rule (SQL profile) and recon tolerances (`.migration/03_recon_tolerances.md`)
  are deliberately the same contract: recon expects exact-to-the-cent equality *because*
  conversion reproduces Redshift truncation. Change one → change both.
- The stored-procedure re-platform (SQL) and the ORCHESTRATION job mapping are one unit:
  `12_sp_refresh_marts` converts to a workflow, not to SQL.

## Drift rules (what gets a unit PR rejected)
1. Converted SQL that relies on Databricks default rounding where Redshift truncates.
2. CHAR-padded comparison literals carried over verbatim (silent empty results).
3. Any `DISTSTYLE/DISTKEY/SORTKEY` syntax left in Databricks DDL.
4. Unit PR without its own recon evidence (counts + aggregates + EXCEPT diffs vs `redshift_src`).
5. PRs targeting `main` instead of the run branch; running legacy `sql/etl/*` on Redshift as the IAM user.
6. New warehouses, hardcoded credentials, or hardcoded workspace hosts.

## Open questions (queued for STOP A, 2026-09-03)
- Re-confirm every PROPOSED field above for run-9 (v1 approvals from 2026-08-28 do not carry over): CI gate = PR-evidence contract; Asset Bundles out of scope; no liquid clustering at current volumes; no medallion re-layering; no dual-write; no masking; decommission criteria; cutover SLA N/A; run branch `migration-run-9`.
- Workflows job for `sp_refresh_marts`: PROPOSED to defer creation to its migration wave (as in v1).
- Loader and BI tool names (currently unnamed in every source) — optional; defaults stand if not supplied.
