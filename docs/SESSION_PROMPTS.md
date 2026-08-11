# Demo Session Prompts

Paste these verbatim when recording. Each session should be started fresh in the
partner-workshops Devin org with this repo attached.

---

## Session 1 — Assessment + Backfill

> We are migrating our Redshift warehouse to Databricks. This repo contains our
> legacy Redshift SQL estate (DDL, nightly ETL, stored procedure, BI reports).
> The live warehouse is Redshift Serverless: workgroup `demo-wg`, database `demo`,
> region `us-east-1`, admin user `demoadmin` (password in org secret
> `REDSHIFT_DEMO_ADMIN_PASSWORD`; AWS access via `AWS_DEMO_ACCESS_KEY_ID` /
> `AWS_DEMO_SECRET_ACCESS_KEY`). Databricks workspace creds are in
> `DATABRICKS_DEMO_HOST` / `DATABRICKS_DEMO_CLIENT_ID` / `DATABRICKS_DEMO_CLIENT_SECRET`.
>
> 1. Inventory every SQL asset in the repo and produce a risk-ranked migration
>    assessment (rank by Redshift-specific features: DISTKEY/SORTKEY, CHAR
>    blank-padding semantics, IDENTITY, GETDATE, DECODE, TRUNC, stored procs).
>    Commit it as docs/ASSESSMENT.md.
> 2. In Databricks: store the Redshift credentials in a secret scope, create a
>    Lakehouse Federation connection + foreign catalog `redshift_src` pointing at
>    the live warehouse, and create Unity Catalog catalog `migration_demo` with
>    schemas `core` and `mart`.
> 3. Backfill `core.customers`, `core.orders`, `core.order_items` into
>    `migration_demo.core` as Delta tables via federation (CTAS from redshift_src).
> 4. Verify against live Redshift: exact row counts, SUM/AVG of order totals to
>    the cent, min/max timestamps. Put the verification table in the PR description.
> 5. Reuse the existing serverless SQL warehouse — do NOT create a new warehouse.
>
> Open a PR with the assessment + any code you wrote.

## Session 2 — SQL Conversion + Reconciliation

> Continue the Redshift→Databricks migration (same credentials as before;
> `migration_demo` and `redshift_src` already exist in the workspace).
>
> 1. Convert the ETL in sql/etl/ and reports in sql/reports/ to Databricks SQL.
>    Preserve source semantics exactly — Redshift-isms like GETDATE, DECODE,
>    TRUNC(timestamp), CHAR blank-padded comparisons, and DECIMAL arithmetic
>    behavior must produce identical results, not just valid syntax.
> 2. Rebuild `migration_demo.mart.daily_revenue` and `migration_demo.mart.customer_ltv`
>    with the converted SQL.
> 3. Run data-level reconciliation against live Redshift via `redshift_src` using
>    the queries in recon/: row counts, per-column aggregates, and row-level diffs
>    for the marts, plus output comparison for every report query. Do not stop at
>    the first PASS/FAIL — if reconciliation fails, diagnose the root cause, fix
>    the CONVERTED sql (never the source), and re-run to green.
> 4. Open a PR with converted SQL under databricks/, plus the reconciliation
>    evidence (before/after if you had to fix anything).

## Fix Session (spawned by webhook — for reference)

The automation passes the failed recon report as the session brief. Expected
behavior: prove whether the converted SQL is wrong vs. the target being stale,
remediate (catch up via federation if freshness drift), re-run recon to green,
open a PR with before/after evidence.
