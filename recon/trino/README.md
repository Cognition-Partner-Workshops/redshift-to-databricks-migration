# Trino → Databricks reconciliation

Source of truth: the Trino snapshot landed in `trino_migration_demo.trino_src` (exported with
`export_snapshot.sql` while the Trino cluster was up). Target: the migrated `core`, `ops` and the
marts rebuilt by `databricks/etl/*`.

Run in order on the SQL warehouse:

1. `01_row_counts.sql` — six objects, `diff` must be 0.
2. `02_aggregates.sql` — per-column sums / min / max / hashed sorted value lists; every row `PASS`.
3. `03_row_diffs.sql` — symmetric `EXCEPT ALL` on both marts; `trino_only = dbx_only = 0`.
4. `04_row_diff_detail.sql` — diagnostic only, shows the mismatching rows.

Report parity: run `trino/sql/reports/2*.sql` on Trino and `databricks/reports/2*.sql` on
Databricks on the same UTC day and diff the CSVs (`docs/evidence/run-N/`).

## Run 2 results (`docs/evidence/run-2/`)

| Check | Result |
|---|---|
| `01_row_counts.sql` — six objects | PASS (`recon_01.tsv`) |
| `02_aggregates.sql` — per-column sums / min / max / hashed value lists | PASS (`recon_02.tsv`) |
| `03_row_diffs.sql` — symmetric diff of both marts | PASS, 0 / 0 rows (`recon_03.tsv`) |
| Report 20 region topline | PASS (`report_diff.txt`) |
| Report 21 channel trend | PASS |
| Report 22 promo lift | **OPEN ITEM** — `median_order_total` differs, and therefore row order |

### Open item: report 22 `median_order_total`

`approx_percentile(order_total, 0.5)` in Trino is a t-digest estimate over `order_total` coerced
to `REAL`. Running the unchanged Trino report three times on the same frozen data gave three
different medians for every promo (e.g. `NONE`: 353.5341, 349.17426, 351.729 — see
`trino_report_22.csv` and `trino_report_22_rerun.txt`), so the Trino output is not reproducible
even against itself. Databricks `percentile_approx` uses a different sketch and returns an
observed value (350.00 for `NONE`); the exact median computed in Trino with a window function is
350.26 (`trino_report_22_rerun.txt`), so neither engine's sketch lands on the true value here. The converted SQL keeps `percentile_approx` (cast to
`FLOAT` to match Trino's `REAL` output type). Every other column of report 22 matches
(`report_22_without_median_and_row_order: PASS`). Closing this needs a business decision on
whether the report should use the exact median (`percentile(order_total, 0.5)`), which is
deterministic on both engines; the difference was not rounded or filtered away.
