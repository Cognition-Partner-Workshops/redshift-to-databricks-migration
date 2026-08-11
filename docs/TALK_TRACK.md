# Demo Talk Track — Devin × Databricks (Redshift Takeout)

Audience: Databricks field teams + prospects migrating to Databricks. Core message:
**Devin is the delivery engine that makes Redshift takeouts faster, cheaper, and
safer.** ~10–12 min. Record per-beat clips, then stitch.

## Tabs to open

| Tab | URL |
|---|---|
| Redshift (query editor v2 or DBeaver/CLI) | https://us-east-1.console.aws.amazon.com/sqlworkbench/home?region=us-east-1 |
| Estate repo | https://github.com/Cognition-Partner-Workshops/redshift-to-databricks-migration |
| Session 1 (assessment + backfill) | _fill in after recording_ |
| PR (assessment/backfill) | _fill in_ |
| Databricks Catalog Explorer (`migration_demo`) | _fill in workspace URL_ |
| Session 2 (SQL conversion + recon) | _fill in_ |
| PR (converted ETL + recon PASS) | _fill in_ |
| Databricks recon job | _fill in_ |
| Devin automations page | https://partner-workshops.devinenterprise.com/automations |
| Fix session (webhook-triggered) | _fill in_ |
| PR (drift fix) | _fill in_ |

---

## 1. Redshift — the customer's starting point (1 min)

Show: `SELECT COUNT(*) FROM core.orders` on `demo-wg`/`demo` (60k+ orders), then the
repo's sql/ tree.

> "This is your prospect on day one: a live Redshift warehouse — still ingesting
> orders — plus years of accumulated DDL, ETL, stored procs, and reports full of
> Redshift-isms: CHAR blank-padding, DISTKEY/SORTKEY, GETDATE, DECODE. **The data
> copy isn't what stalls Redshift takeouts — this estate of logic is.** Every query
> must be rewritten and proven equivalent before cutover. That's the months of
> PS/SI effort that stretches deal timelines."

## 2. Session 1 — Devin assesses and lands the data (2 min)

Show: session 1's risk-ranked assessment, then the PR's verification table.

> "We gave Devin the repo plus AWS and Databricks credentials — nothing else. In one
> session it inventoried every SQL asset, ranked migration risk by Redshift-specific
> feature, created the Unity Catalog target, and backfilled the core tables using
> your own platform primitives — Lakehouse Federation, Delta, the SQL warehouse.
> Then it verified against live Redshift: row counts exact, aggregates to the cent."
>
> Sales angle: "The discovery + landing phase that normally burns weeks — done in
> one autonomous session, with an auditable PR as the deliverable."

## 3. Databricks — the migrated warehouse (1 min)

Show: Catalog Explorer — `migration_demo` (core + mart) next to `redshift_src`.

> "Everything lives natively in the customer's workspace: `migration_demo` is the
> migrated Delta catalog; `redshift_src` is live Redshift federated in — that's what
> lets us reconcile against the moving source continuously. Devin drives Databricks
> like a staff engineer: warehouse SQL, UC catalogs, jobs, secret scopes, all via
> standard APIs, all auditable in query history."

## 4. Session 2 — transpilation, proven equivalent (2–3 min)

Show: session 2 where recon first FAILED, the diagnosis, then the PASS evidence.

> "This session converted the ETL and reports and rebuilt the marts. The money
> moment: its own reconciliation caught a real divergence — customers' average order
> value off by one cent. Redshift truncates decimal AVG; Databricks rounds. Both
> engines are 'correct.' No transpiler flags it; only data-level reconciliation
> against live Redshift does. Devin diagnosed it, fixed the converted SQL to
> preserve source semantics, and proved parity: counts, aggregates, row-level diffs."
>
> Sales angle: "**Transpilers get you syntax; the last mile is semantics — that
> last mile is what makes customers afraid to cut over.** Devin closes it with
> evidence, and fans out parallel sessions across the rest of the estate."

## 5. Event-driven loop — Databricks job triggers Devin (2–3 min)

Setup: run `python scripts/drift_loader.py` ~10 min before (new orders land in
Redshift; the migrated copy goes stale). Live: **Run now** on the recon job → red →
automations page shows a session spawning. Fallback: show a past red run + the
finished fix session.

> "Migration is a parallel-run period — the source keeps moving. So reconciliation
> runs as a Databricks job every night, comparing live Redshift via federation
> against the migrated catalog. Green — nothing happens. Red — the job POSTs the
> failure report to a Devin webhook, and Devin starts fixing before a human has
> read the alert."

## 6. Fix session — autonomous remediation (2 min)

Show: fix session + PR.

> "Watch its reasoning: it did *not* assume the conversion was broken. It proved
> the converted SQL correct, identified freshness drift — the target was simply
> behind the live source — caught the catalog up through federation, re-ran
> reconciliation to green, and opened a PR with before/after evidence. Minutes,
> a few dollars of compute, zero humans."

## Close (30s)

> "Devin worked the entire surface: Redshift as source, GitHub for deliverables,
> Databricks as the platform — federation, Delta, UC, warehouses, jobs, secrets —
> plus transpilation with semantic proof and event-driven remediation triggered by
> Databricks itself. Redshift takeout assessments in days not weeks, cutover with
> evidence instead of fear, and a parallel-run period that doesn't burn PS hours.
> **Devin makes the migration the fast part of the deal.**"

---

## Mechanics / cautions

- Beat 5 needs staging: run the drift loader ~10 min before. Without it, Run now
  comes back green (no webhook, no session).
- Reuse the existing serverless SQL warehouse — do not create new warehouses.
- Redshift Serverless bills only on active compute; the estate reseeds in ~15 min
  via `scripts/seed_redshift.py` if the environment is ever torn down.
