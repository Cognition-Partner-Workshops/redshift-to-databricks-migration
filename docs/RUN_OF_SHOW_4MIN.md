# 4-Minute Run of Show — Devin × Databricks (Redshift Takeout)

Same story as TALK_TRACK.md, compressed to ~4 minutes. Rule: **nothing runs live
except one click** (Run Now on the recon job — optional). Everything else is
pre-staged by the `!rs_demo_stage` playbook, and the demo is a fast walk through
finished artifacts.

Fill in the URLs for the current take (the stage playbook outputs them):

| # | Artifact | URL |
|---|---|---|
| 1 | Redshift query (console QEv2 or DBeaver) | `<fill>` |
| 2 | Estate repo (`main`, sql/ tree) | https://github.com/Cognition-Partner-Workshops/redshift-to-databricks-migration |
| 3 | Session 1 + its PR (assessment/backfill) | `<fill>` / `<fill>` |
| 4 | Databricks Catalog Explorer (`migration_demo` + `redshift_src`) | `<fill>` |
| 5 | Session 2 PR — recon FAIL→PASS evidence | `<fill>` |
| 6 | Recon job (red run staged) | `<fill>` |
| 7 | Fix session + its PR | `<fill>` / `<fill>` |

Pre-open all tabs in order. Practice the tab-switch rhythm once — the 4 minutes
is entirely pacing.

---

## 0:00–0:30 — The problem (Redshift estate)

Show: `SELECT COUNT(*) FROM core.orders` (60k+, still ingesting) → flip to the
repo's `sql/` tree.

> "A live Redshift warehouse plus years of DDL, ETL, and reports full of
> Redshift-isms. The data copy isn't what stalls a takeout — this estate of
> logic is. Every query has to be rewritten and *proven equivalent*. That's the
> months of effort that stretch these deals."

## 0:30–1:15 — One session: assess + land the data

Show: Session 1's risk-ranked assessment (scroll the risk table), then the PR's
verification table.

> "We gave Devin the repo and credentials — nothing else. One autonomous session:
> inventoried the estate, ranked risk by Redshift-specific feature, created the
> Unity Catalog target, backfilled via Lakehouse Federation, and verified against
> live Redshift — row counts exact, aggregates to the cent. Weeks of discovery,
> one session, an auditable PR."

## 1:15–2:15 — The money moment: proven equivalence

Show: Session 2 PR — initial recon FAIL, the one-line diagnosis, the final
all-green table. (Optionally flash Catalog Explorer: `migration_demo` next to
`redshift_src`.)

> "Next session converted the ETL and rebuilt the marts — and its own
> reconciliation caught a real divergence: average order value off by one cent.
> Redshift truncates decimal AVG; Databricks rounds. Both engines are 'correct',
> no transpiler flags it — only data-level reconciliation against the live source
> does. Devin diagnosed it, fixed its own conversion to preserve source
> semantics, and proved parity: counts, aggregates, row-level diffs, all green.
> Transpilers get you syntax; **Devin closes the semantic last mile with
> evidence.**"

## 2:15–3:30 — Databricks triggers Devin

Staged: drift already injected; job schedule paused. Live click: **Run Now** on
the recon job → it goes red (~30s) → flip to the already-finished fix session
from staging while it spawns. (Zero-risk alternative: skip the click, show the
staged red run directly.)

> "Migration is a parallel-run period — the source keeps moving. So recon runs as
> a Databricks job. Red run → the job POSTs its failure report to a Devin
> webhook — Devin starts fixing before a human reads the alert. Watch the
> reasoning: it *proved the conversion correct*, identified freshness drift,
> caught the catalog up through federation, re-ran recon to green, and opened an
> audit PR. Minutes, a few dollars of compute, zero humans."

## 3:30–4:00 — Close

> "Devin worked the whole surface — Redshift, GitHub, and Databricks natively:
> federation, Delta, Unity Catalog, warehouses, jobs. Assessment in hours,
> cutover with evidence instead of fear, and a parallel run that doesn't burn PS
> hours. **Devin makes the migration the fast part of the deal.**"

---

## Cautions

- Stage with `!rs_demo_stage` (fresh `migration-run-N`, sessions pre-run, drift
  injected, job paused) — never demo on a stale take.
- If doing the live Run Now: the red run takes ~30s; keep talking over it. If
  anything hiccups, pivot to the staged red run + finished fix session.
- Don't show `demo-ops` or this file on screen; only `main` and the run branch.
