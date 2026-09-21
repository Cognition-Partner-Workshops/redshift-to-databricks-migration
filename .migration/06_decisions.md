# Decisions

| ID | Date | Provenance | Decision |
|---|---|---|---|
| D-1 | 2026-09-21 | default-accepted | Report 22 `approx_percentile` (Trino T-Digest) and `percentile_approx` (Databricks) are not a like-for-like contract. The target report uses exact `percentile(order_total, 0.5)`. Reconciliation compares exact percentile results computed on both sides by query; the Trino query is read-only. Approximate source values are excluded from Tier 3. No tolerance is introduced. |
| D-2 | 2026-09-21 | default-accepted | Marts reconcile from the run-1 snapshot landing in `trino_src`. This is DEGRADED because there is no Trino source adapter. The blast radius is that mart parity is proven against Trino-computed snapshot rows, not a live reread. |
| D-3 | 2026-09-21 | default-accepted | Legacy PostgreSQL is reached through the compose DSN. Credentials already exist in `trino/docker-compose.yml`; `TRINO_OPS_DSN` is built in-shell only and never committed. |
| D-4 | 2026-09-21 | default-accepted | Allowlist establishes `trino_migration_demo` as the sole write catalog and `TRINO_OPS_DSN` as the named read-only legacy source; default-accepted, demo. |
