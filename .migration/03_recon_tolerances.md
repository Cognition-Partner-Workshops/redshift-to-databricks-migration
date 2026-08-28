# 03 — Reconciliation Tolerances (parity contract)

Version: v1 (2026-08-28) — all rows PROPOSED pending STOP A confirmation.
Recon mode: **LIVE** (Lakehouse Federation to live Redshift via `redshift_src`).

## Tolerances (per data type, SQL/PIPELINE surface)

| Data type / check | Tolerance | Rationale | Status |
|---|---|---|---|
| Row counts (all 5 tables) | 0 (exact) | Full-refresh CTAS lineage | PROPOSED |
| Integers / keys | exact | — | PROPOSED |
| DECIMAL sums (order_total, revenue) | exact to the cent (DECIMAL(38,2)) | Conversion reproduces Redshift truncation | PROPOSED |
| DECIMAL averages / division outputs (AOV, LTV) | exact at legacy output scale (4 dp), using the truncation-reproduction rule `SIGN(x)*FLOOR(ABS(x), scale)` | Redshift truncates toward zero; Databricks rounds | PROPOSED |
| Timestamps | exact; report DATE columns compared after stripping ` 00:00:00` from Redshift Data API rendering | Rendering artifact, not a value difference | PROPOSED |
| CHAR(n) strings | compare RTRIM(legacy) = migrated STRING | Blank-padding semantics | PROPOSED |
| Row-level diffs | 4 EXCEPT diffs (both directions, marts) = 0 rows | — | PROPOSED |
| Nondeterminism | none known (no unordered ties in mart grain); any tie-break issue escalates, never tolerated silently | — | PROPOSED |
| ML prediction parity | N/A — no ML workloads | — | FACT |

## Recon economics

| Parameter | Value | Status |
|---|---|---|
| Row-level diff threshold | full EXCEPT diffs up to 10M rows/table; above that, keyed stratified sample (1%) + full aggregates. Current estate max ≈ 63k orders → always full diffs | PROPOSED |
| Legacy-query concurrency cap | 2 concurrent recon queries against Redshift `demo-wg` | PROPOSED |

## Drift protocol
Count/diff mismatch with fresh `redshift_src` rows newer than the last core resync = drift,
not a conversion bug: resync `migration_demo.core.*` from federation, rebuild both marts,
re-run recon before judging parity.

## Amendment procedure
A tolerance changes only by explicit user approval, recorded as a new dated version below
(old row preserved), with a stated re-verification scope for waves already merged under the
old tolerance.

## Version history
- v1 (2026-08-28): initial proposal, all rows PROPOSED.
