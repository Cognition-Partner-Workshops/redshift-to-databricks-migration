# 06 — Decision Log

| Date | Decision | Owner | Rationale |
|---|---|---|---|
| 2026-08-28 | Run branch `migration-run-6` created from `main`; PRs target it, never `main` | Devin (per repo demo-layout convention) | `main` is the pristine pre-migration estate |
| 2026-08-28 | Federation-first coexistence (LIVE recon mode) via existing `redshift_src` catalog | Devin (probed & verified) | JDBC path exists and works |
| 2026-08-28 | Refreshed stale credential on UC connection `redshift_demo` to restore federation | Devin | All federation reads failed; direct psql with current admin password succeeded |
| 2026-08-28 | STOP A: all PROPOSED tolerances and target-state defaults approved as proposed (incl. deferring the `sp_refresh_marts` replacement job to its migration wave) | user | Explicit approval in-session |
