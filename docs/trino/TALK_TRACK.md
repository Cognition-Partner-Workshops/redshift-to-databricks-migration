# Demo Talk Track — Devin × Databricks (Trino Takeout)

Audience: Databricks field teams + prospects running Trino/Presto (Starburst,
Athena, EMR Presto) on a Hive/S3 lake. Core message: **the Trino estate is
federated SQL logic; Devin converts it and proves it equivalent, so the move to
Unity Catalog is the fast part.** ~6–8 min. Same rhythm as the Redshift track.

## Tabs to open

| Tab | URL |
|---|---|
| Estate repo (`trino-estate` branch, `trino/` tree) | https://github.com/Cognition-Partner-Workshops/redshift-to-databricks-migration/tree/trino-estate/trino |
| Rehearsal PR — conversion + recon FAIL→PASS | https://github.com/Cognition-Partner-Workshops/redshift-to-databricks-migration/pull/36 |
| Visual summary (self-contained HTML) | `docs/trino/artifacts/trino_migration_run1.html` on `demo-ops` (download and open locally) |
| Databricks Catalog Explorer (`trino_migration_demo`) | https://dbc-8bc9474f-40ae.cloud.databricks.com/explore/data/trino_migration_demo |
| AI/BI dashboard (marts + live recon scorecard) | https://dbc-8bc9474f-40ae.cloud.databricks.com/dashboardsv3/01f1b5cea39d13d3b9853ac273af0079/published |
| Rehearsal session | https://partner-workshops.devinenterprise.com/sessions/0d1e5d04a67b409f9073df195cc549ce |

Notes: the Trino estate lives on branch `trino-estate` (`main` stays the pristine
Redshift estate). Runs PR into `trino-migration-run-N`, never into `trino-estate`.
Trino itself runs in Docker on the operator's machine (`cd trino && make all`,
~1 min), so the Databricks side loads a CSV snapshot into `trino_src` instead of
federating live. If you have a reachable Trino/Postgres, swap the snapshot step for
Lakehouse Federation — the prompts below say where.

---

## 1. Trino — the customer's starting point (1 min)

Show: `trino/sql/` tree, then `sql/etl/11_build_customer_ltv.sql` (cross-catalog
join, `array_agg ... ORDER BY`, `date_diff`) and `sql/reports/22_promo_lift.sql`
(`map_entries` + `UNNEST`, `approx_percentile`).

> "Trino is a query engine, not a warehouse. It sits over a Hive/Parquet lake and
> a live Postgres and joins them in one SQL statement. So the estate is not tables —
> it's federated logic in the Trino dialect: maps, unnest, approximate aggregates,
> cross-catalog joins. Every one of those has to be rewritten into Databricks SQL
> and proven to return the same numbers. **That, not the data copy, is the
> takeout.**"

## 2. Devin assesses, lands, converts (1.5 min)

Show: PR #36 description → `docs/ASSESSMENT.md` risk table, then the
`databricks/` tree.

> "One session, one repo, Databricks credentials. Devin inventoried the eight
> assets, ranked them by Trino-specific risk, landed all six source objects in
> Unity Catalog — Postgres side and lake side in one Delta catalog — and converted
> ETL and reports. Note the conversions that aren't one-to-one: `map_entries`
> plus `UNNEST` becomes `LATERAL VIEW EXPLODE`; `array_agg ORDER BY` becomes
> `array_sort(collect_set)`."

## 3. The money moment — recon caught what a transpiler can't (2 min)

Show: PR #36 `docs/evidence/run-1/recon_before.md` → `recon_after.md`, or the
"What reconciliation caught" section of the HTML summary.

> "First recon run: counts perfect, aggregates perfect — and 95 of 150 customers
> had a different `active_days`, 15 daily rows had a different average order
> value. Both queries were valid SQL. Trino's `date_diff('day')` counts elapsed
> 24-hour periods; Spark's `DATEDIFF` counts midnight crossings. Trino keeps
> decimal division at scale 2; Spark widens it. Devin diagnosed both from the
> row-level diff, fixed the *converted* SQL — never the source — and re-ran to
> zero differences."
>
> Sales angle: "**Transpilers get you syntax. Reconciliation gets you semantics.**
> Devin does the second part, with evidence, and opens the PR."

## 4. Databricks — the migrated estate, live (1 min)

Show: Catalog Explorer `trino_migration_demo` (core, ops, mart, trino_src), then
the AI/BI dashboard: revenue by week/region, and the recon scorecard widget
showing Trino vs Databricks side by side.

> "This is the customer's workspace: one Unity Catalog with the former lake tables
> and the former Postgres tables side by side, marts rebuilt with converted SQL,
> and a dashboard that reads the reconciliation live — every row says MATCH."

## 5. The honest open item (30s)

Show: dashboard note / HTML summary finding C (report 22 promo ranking).

> "One thing Devin didn't hide: the promo report's median uses an approximate
> percentile on both engines, and the two estimators disagree enough to reorder
> the ranking. Both are 'correct'. Devin flagged it as a business decision — pick
> one exact definition — rather than silently rounding it away. That's the
> behavior you want from something touching your numbers."

## Close (30s)

> "Trino to Databricks: federated query logic converted, landed in Unity Catalog,
> and proven equivalent row by row — in a single session, with a PR you can
> review. **Devin makes the migration the fast part of the deal.**"

---

## Mechanics / cautions

- Reuse the existing serverless SQL warehouse — do not create new warehouses or
  clusters.
- To re-stage a run: `git checkout -b trino-migration-run-N origin/trino-estate`,
  push it, then start the session with the prompt in `SESSION_PROMPTS.md`.
- The HTML summary is static evidence from run 1; regenerate numbers if the
  estate seed changes.
