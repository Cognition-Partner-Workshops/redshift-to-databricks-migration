# Trino Demo Session Prompts

Paste verbatim. Start a fresh session in the partner-workshops Devin org with
this repo attached, on branch `trino-migration-run-N` (cut from `trino-estate`).

---

## Session — Land, convert, reconcile (single session)

> We are migrating our Trino order-analytics estate to Databricks. This repo's
> `trino/` directory is the source estate: a Trino cluster with a Hive/Parquet
> `lake` catalog (schemas `core`, `mart`) and a PostgreSQL `ops` catalog, plus DDL,
> seed, nightly ETL and reports in the Trino dialect. Bring it up locally with
> `cd trino && make all` (Docker; ~1 min). Databricks workspace credentials are
> `DATABRICKS_DEMO_HOST` / `DATABRICKS_DEMO_TOKEN`; use the existing SQL
> warehouse — do NOT create a warehouse or cluster.
>
> 1. Inventory every SQL asset under `trino/sql` and write a risk-ranked
>    assessment (rank by Trino-specific features: cross-catalog joins, MAP +
>    UNNEST, array_agg ORDER BY, approx_distinct / approx_percentile, date_diff,
>    format_datetime). Commit it as docs/ASSESSMENT.md.
> 2. Land all six source objects (lake.core.orders, lake.core.order_items,
>    ops.public.customers, ops.public.customer_tags, lake.mart.daily_revenue,
>    lake.mart.customer_ltv) into Unity Catalog catalog `trino_migration_demo`
>    (schemas `core`, `ops`, `mart`; raw snapshot in `trino_src`). The Trino
>    cluster is not reachable from the workspace, so export CSV snapshots from
>    Trino and load them via a UC volume. Preserve types exactly, including the
>    MAP attrs column and the CHAR(4) region values.
> 3. Convert the ETL and reports to Databricks SQL under `databricks/`. Preserve
>    semantics, not just syntax — date_diff, decimal arithmetic scale, ordered
>    distinct arrays and map unnesting must return identical results.
> 4. Rebuild `mart.daily_revenue` and `mart.customer_ltv` with the converted SQL
>    and reconcile against the Trino snapshot: row counts for all six objects,
>    per-column aggregates, symmetric row-level diffs, and output comparison for
>    every report. If anything differs, diagnose the root cause, fix the
>    CONVERTED SQL (never the source), and re-run to green. Report any
>    difference you cannot legitimately close as an open item — do not round or
>    filter it away.
> 5. Open a PR into this run branch with the assessment, converted SQL, recon
>    queries under recon/trino/, and before/after evidence under
>    docs/evidence/.

## Variant — live federation instead of snapshot

If Trino/Postgres are reachable from the Databricks workspace, replace step 2's
snapshot instruction with:

> Create a Lakehouse Federation connection to the operational PostgreSQL and a
> foreign catalog `ops_src`; land the lake tables from their Parquet location via
> an external location. Reconcile against the live sources, not a snapshot.

## Follow-up — visual artifacts (optional)

> Build an AI/BI dashboard on `trino_migration_demo.mart` (revenue by week and
> promo group, revenue by region, AOV by promo) with a reconciliation widget that
> shows Trino snapshot vs Databricks values side by side with a MATCH/MISMATCH
> column. Publish it and add the dashboard JSON to the PR.
