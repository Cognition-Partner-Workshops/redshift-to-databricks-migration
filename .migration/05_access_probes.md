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
