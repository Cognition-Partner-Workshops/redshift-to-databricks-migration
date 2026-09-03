# 06 — Decision Log

Provenance values: `user:<id>` (explicit reply), `default-accepted (soft, 60s, no reply)`, `Devin (probed)`.
Blast radius: what is affected if the decision is later reversed.

| Date | Stop / step | Decision | Provenance | Blast radius |
|---|---|---|---|---|
| 2026-09-03 | intake | Engine pinned: Redshift Serverless `1.0.416217`, `demo-wg`/`demo`, us-east-1; dialect skill `redshift-sql` attached | Devin (probed) | dictionary + inventory keyed to this dialect |
| 2026-09-03 | intake | `stop_mode` = soft (60-second default acceptance); STOP E always hard | default (user may reply "stop_mode hard") | governs every later stop |
| 2026-09-03 | intake | Federation-first coexistence and LIVE recon via existing read-only `redshift_demo`/`redshift_src` (verified: 64,397 orders) | Devin (probed) — user re-confirms at STOP A | recon mode, coexistence method, D2 dependencies |
| 2026-09-03 | intake | Query history carries no consumer evidence → DEP-001 D4 gap; sweep falls back to user-declared landscape | Devin (probed) | D4 sweep confidence; cutover consumer list |
| 2026-09-03 | setup | Run branch `migration-run-9` from `main`; `main` stays pristine; unit PRs target the run branch | Devin (repo convention) — confirm at STOP A | every branch/PR of this run |
| 2026-09-03 | setup | Target-state v2 and tolerances v2 re-proposed from run-6 v1 (values unchanged; probes refreshed). Prior approvals do not carry over | Devin | STOP A scope |
| 2026-09-03 | setup | Prior-run converted code (`origin/devin/1786578025-sql-conversion-recon-run4`, `databricks/**`) is a reference implementation only; run-9 re-derives each unit through the standard chain and recon | Devin | conversion effort; no shortcut of recon gating |
