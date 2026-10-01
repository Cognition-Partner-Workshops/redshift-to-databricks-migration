# 02 — Glossary

- **Core schema**: normalized, append-only landing zone for raw transactional data.
- **Mart schema**: denormalized aggregates for BI (daily_revenue, customer_ltv).
- **Drop + CTAS**: legacy full-refresh strategy for nightly mart rebuilds.
- **Recon**: automated comparison of counts/aggregates/row diffs between Redshift and Databricks.
- **Drift**: divergence caused by fresh source records landing in Redshift mid-migration (may be injected by `scripts/drift_loader.py` on demo-ops).
- **Federation / `redshift_src`**: live Databricks foreign catalog into Redshift via UC connection `redshift_demo`.
- **LTV / AOV**: lifetime value per customer / average order value.
- **Report parity**: identical report output across both dialects (after stripping ` 00:00:00` from Redshift Data API date rendering).
- **Run branch**: `migration-run-N` integration branch; `main` stays pristine.
