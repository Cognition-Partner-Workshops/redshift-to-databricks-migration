# Access probes — workspace-setup, plan revision 24

Run on 2026-10-01 from the worker session for ticket UNT2-2, under dbx-migration-factory 0.5.0
with the committed `.migration/allowed_targets.json` in force. Legacy is read-only; no `sql/etl/*`
file was executed anywhere.

| # | Probe | Result | Evidence |
|---|---|---|---|
| 1 | Databricks identity (OAuth M2M, no PAT) | WORKS | `databricks current-user me` → service principal `d9d1c4ec-29da-4ec7-9aa0-e932710d61e2` (DE-shared), host = `$DATABRICKS_DEMO_HOST` |
| 2 | Databricks SQL on warehouse `565cd2fd713738c4` | WORKS | `SELECT 1 AS ok` returned 1 |
| 3 | Redshift principal `devin-redshift-demo` | WORKS | `aws sts get-caller-identity` with `$AWS_DEMO_ACCESS_KEY_ID` / `$AWS_DEMO_SECRET_ACCESS_KEY` → `arn:aws:iam::599083837640:user/devin-redshift-demo` |
| 4 | Redshift Data API read on `core` (`SELECT count(*) FROM core.orders`, workgroup `demo-wg`, db `demo`) | BLOCKED | `dbx_guard`: "unrecognised command `aws` names legacy connection ['demo']; the guard cannot verify its operation". The guard has no rule for `aws redshift-data`; the blueprint helper `~/rs_sql.py` (boto3) is refused the same way ("statement built at run time against legacy source"). Not a Redshift permission failure: the statement was never sent. |
| 5 | Redshift Data API read on `mart` (`SELECT count(*) FROM mart.daily_revenue`) | BLOCKED | same as 4 |
| 6 | Federated read `redshift_src.core.*` (`SELECT count(*) FROM redshift_src.core.orders`) | BLOCKED | Databricks: `User does not have USE CATALOG on Catalog 'redshift_src'` (service principal `d9d1c4ec-…`) |
| 7 | Federated read `redshift_src.mart.*` (`SELECT count(*) FROM redshift_src.mart.daily_revenue`) | BLOCKED | same error on `redshift_src` |
| 8 | Write to `migration_demo.core` (`CREATE TABLE migration_demo.core._probe …`) | BLOCKED | Databricks: `User does not have USE CATALOG on Catalog 'migration_demo'`; the catalog is not visible to the principal (`databricks catalogs list` shows wwi_dev, ow_tp, system, samples, de_demo_workspace only) |
| 9 | Write to `migration_demo.mart` | BLOCKED | same error on `migration_demo` |
| 10 | `dbx_guard` blocks a write to `redshift_src` (`CREATE TABLE redshift_src.core._probe …`) | BLOCKED (expected) | guard: "write to catalog(s) ['redshift_src'] outside allowlist ['migration_demo']" — the client never ran |
| 11 | factory-doctor, setup posture, with hook probe | BLOCKED | `dbx_guard` refuses the documented command `python3 <plugin>/skills/factory-doctor/doctor.py --workspace <repo> --role setup …`: "Python statement or connection is built at run time; the guard cannot resolve a non-read statement" (reproduced by feeding the exact command to `hooks/dbx_guard.py`). The doctor never ran, so no `09_capabilities.json` was produced and no `.hook_probe_nonce` exists. |

## Findings for the manager (plan blockers, not things to route around)

1. Grants: the migration service principal `d9d1c4ec-29da-4ec7-9aa0-e932710d61e2` needs `USE CATALOG`
   on `migration_demo` and `redshift_src`, `USE SCHEMA` + `SELECT` on `redshift_src.core` /
   `redshift_src.mart`, and `USE SCHEMA` + `CREATE TABLE` + `MODIFY` on `migration_demo.core` /
   `migration_demo.mart`. Probes 6–9 re-run once granted. If `migration_demo` does not exist yet it
   must be created by the human/admin (a session cannot create a catalog it is not allowed to see).
2. Guard vs. Data API: `dbx_guard` 0.5.0 has no rule for `aws redshift-data` or the boto3 helper, so
   the Redshift Data API read probe cannot be executed by any session under the guard. Either the
   plugin gains a read-only rule for `aws redshift-data execute-statement`, or the plan accepts
   federation (probes 6–7) as the only legacy read path.
3. Guard vs. doctor: `dbx_guard` 0.5.0 blocks `factory-doctor/doctor.py` itself (probe 11). Gate
   `g-doctor` cannot be signed until the plugin exempts its own doctor or the doctor avoids the
   dynamic-statement shapes the guard flags.

## Probes 6–9 per Databricks principal (manager follow-up, 2026-10-01)

The intake names two Databricks identities. Both are listed; only one may be used for migration work.

| Principal | Secret names | Auth type | Probes 6–7 (federated read `redshift_src`) | Probes 8–9 (write `migration_demo`) |
|---|---|---|---|---|
| Service principal `d9d1c4ec-29da-4ec7-9aa0-e932710d61e2` (DE-shared) | `DATABRICKS_HOST`, `DATABRICKS_CLIENT_ID`, `DATABRICKS_CLIENT_SECRET` | `oauth-m2m` | BLOCKED — `User does not have USE CATALOG on Catalog 'redshift_src'` | BLOCKED — `User does not have USE CATALOG on Catalog 'migration_demo'` |
| "Migration principal" per intake | `DATABRICKS_DEMO_HOST`, `DATABRICKS_DEMO_TOKEN` | `pat` | NOT PROBED — forbidden by `target-routing` (quoted below) | NOT PROBED — forbidden by `target-routing` (quoted below) |

`dbx-migration-factory/skills/target-routing/SKILL.md`, "Databricks auth" (the only home for the auth rules):

> Worker sessions run as the engagement's dedicated **migration service principal**, configured by the
> org blueprint: OIDC token federation preferred (`DATABRICKS_AUTH_TYPE=env-oidc` …), OAuth M2M fallback
> (`DATABRICKS_AUTH_TYPE=oauth-m2m` with `DATABRICKS_CLIENT_SECRET`). Auth arrives only from env vars the
> blueprint sets (`DATABRICKS_HOST`, `DATABRICKS_CLIENT_ID`) … **No PATs (the doctor fails a `pat` session;
> there is no waiver)**, no profiles, no config files, no interactive `databricks auth login`.

`skills/factory-doctor/references/checks.md`, `databricks_identity`:

> `env-oidc` or `oauth-m2m` is `ok`, `pat` is a `fail` that attributes work to a human and bypasses the
> service principal (a plan decision cannot waive it).

Consequence: `DATABRICKS_DEMO_TOKEN` cannot be the migration principal under factory 0.5.0, and the
doctor would fail the workspace if it were. The identity that can satisfy `g-doctor` is the OAuth
service principal `d9d1c4ec-…`; it needs the grants listed under "Findings for the manager" above
(`USE CATALOG` on `migration_demo` and `redshift_src`, schema-level `SELECT` on `redshift_src.core|mart`,
`CREATE TABLE`/`MODIFY` on `migration_demo.core|mart`). If the intake intends a different service
principal as the migration identity, that is a plan decision and a blueprint change, not a probe.
