# Reconciliation Harness

Data-level parity checks between live Redshift (federated in as `redshift_src`)
and the migrated catalog (`migration_demo`). Run on the Databricks SQL warehouse.

- `01_row_counts.sql` — exact row counts for every migrated table
- `02_aggregates.sql` — per-column SUM/AVG/MIN/MAX to the cent
- `03_row_diffs.sql` — row-level EXCEPT diffs for the marts

A migration is GREEN only when every query returns zero mismatches. These are the
queries the nightly Databricks recon job runs; on failure the report is POSTed to
the Devin webhook.
