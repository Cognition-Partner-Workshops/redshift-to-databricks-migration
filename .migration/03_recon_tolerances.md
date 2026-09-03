# 03 — Reconciliation Tolerances (parity contract)

Version: v2 (2026-09-03, run `migration-run-9`) — every row below is **PROPOSED** for this run's STOP A.
v1 (2026-08-28, run-6) carried identical values and was confirmed then; the "CONFIRMED (STOP A 2026-08-28)"
markers are kept as provenance of v1 only and do not count as approval for run-9.
Recon mode: **LIVE** (Lakehouse Federation to live Redshift via `redshift_src`, verified 2026-09-03: 64,397 orders).

Populations: row-count and EXCEPT tolerances are computed over every row of each of the 5 in-scope tables
(`core.customers`, `core.orders`, `core.order_items`, `mart.daily_revenue`, `mart.customer_ltv`); aggregate
tolerances over the full table; report-parity over the complete report result set. No sampling at current volumes.

## Tolerances (per data type, SQL/PIPELINE surface)

| Data type / check | Tolerance | Rationale | Status |
|---|---|---|---|
| Row counts (all 5 tables) | 0 (exact) | Full-refresh CTAS lineage | CONFIRMED (STOP A 2026-08-28) |
| Integers / keys | exact | — | CONFIRMED (STOP A 2026-08-28) |
| DECIMAL sums (order_total, revenue) | exact to the cent (DECIMAL(38,2)) | Conversion reproduces Redshift truncation | CONFIRMED (STOP A 2026-08-28) |
| DECIMAL averages / division outputs (AOV, LTV) | exact at legacy output scale (4 dp), using the truncation-reproduction rule `SIGN(x)*FLOOR(ABS(x), scale)` | Redshift truncates toward zero; Databricks rounds | CONFIRMED (STOP A 2026-08-28) |
| Timestamps | exact; report DATE columns compared after stripping ` 00:00:00` from Redshift Data API rendering | Rendering artifact, not a value difference | CONFIRMED (STOP A 2026-08-28) |
| CHAR(n) strings | compare RTRIM(legacy) = migrated STRING | Blank-padding semantics | CONFIRMED (STOP A 2026-08-28) |
| Row-level diffs | 4 EXCEPT diffs (both directions, marts) = 0 rows | — | CONFIRMED (STOP A 2026-08-28) |
| Nondeterminism | none known (no unordered ties in mart grain); any tie-break issue escalates, never tolerated silently | — | CONFIRMED (STOP A 2026-08-28) |
| ML prediction parity | N/A — no ML workloads | — | FACT |

## Recon economics

| Parameter | Value | Status |
|---|---|---|
| Row-level diff threshold | full EXCEPT diffs up to 10M rows/table; above that, keyed stratified sample (1%) + full aggregates. Current estate max ≈ 63k orders → always full diffs | CONFIRMED (STOP A 2026-08-28) |
| Legacy-query concurrency cap | 2 concurrent recon queries against Redshift `demo-wg` | CONFIRMED (STOP A 2026-08-28) |

## Drift protocol
Count/diff mismatch with fresh `redshift_src` rows newer than the last core resync = drift,
not a conversion bug: resync `migration_demo.core.*` from federation, rebuild both marts,
re-run recon before judging parity.

## Amendment procedure
A tolerance changes only by explicit user approval, recorded as a new dated version below
(old row preserved), with a stated re-verification scope for waves already merged under the
old tolerance.

## Version history
- v1 (2026-08-28): initial proposal; confirmed as-is at STOP A the same day (run-6).
- v2 (2026-09-03): same values re-proposed for run-9 with explicit populations; pending STOP A.
