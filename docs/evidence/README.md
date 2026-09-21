# Evidence: Trino -> Databricks

All Trino output was taken from the running estate (`cd trino && make all`, 2026-09-21 UTC). All Databricks output
came from the existing SQL warehouse through `databricks/run_sql.py`.

## before/ (Trino)

| File | What |
|---|---|
| `source_schemas_and_counts.tsv` | `SHOW COLUMNS` and `count(*)` for the six source tables |
| `export.sh` | the CSV export that was run (`trino --output-format CSV_HEADER`; map/array columns as JSON) |
| `csv_export_manifest.txt` | md5 and line count of each exported CSV |
| `report_20_region_topline.tsv`, `report_21_channel_trend.tsv` | report output on Trino |
| `report_22_promo_lift_run1..3.tsv` | the same report three times; `median_order_total` differs every run |
| `promo_lift_median_check.tsv` | two `approx_percentile` calls in one statement agree with each other but not with the other runs |
| `approx_distinct_vs_exact.tsv` | 0 mart rows where `approx_distinct` differs from the exact distinct count |
| `date_diff_semantics.tsv` | Trino `date_diff('day')` on timestamps counts whole 24h spans; 94 customers would change under calendar-day semantics |

## after/ (Databricks)

| File | What |
|---|---|
| `target_schemas.tsv` | `DESCRIBE` of all 12 target tables (six `trino_src` snapshots, six migrated) |
| `etl_rebuild.log` | the two converted ETL statements running |
| `recon_01_row_counts.tsv` | 6 tables, all diffs 0 |
| `recon_02_column_aggregates.tsv` | 17 columns across both marts, all diffs 0 |
| `recon_03_symmetric_row_diff.tsv` | `EXCEPT ALL` both ways for 6 tables, all 0 |
| `recon_03b_symmetric_row_diff_detail.tsv` | detail rows behind any diff (empty) |
| `recon_04_report_parity.tsv` | reports 20 and 21 identical on rebuilt vs snapshot marts; report 22 median is a true middle value and `AVG` diff 0 |
| `report_20_region_topline.tsv`, `report_21_channel_trend.tsv` | converted report output; identical to `before/` |
| `report_22_promo_lift_run1.tsv`, `run2.tsv` | converted report twice; identical to each other |
| `mart_customer_ltv_sample.tsv` | first five rows of the rebuilt mart |

## Result

Row counts, per-column aggregates, symmetric row diffs and reports 20/21 all reconcile to zero on the first rebuild
after conversion. No converted SQL was changed to make recon pass; the two follow-up edits (`CAST(AVG(...) AS
DECIMAL(12,2))` in reports 20 and 22) only restored Trino's output scale, the values were already equal.

Open item: `22_promo_lift.sql` `median_order_total`. Trino's `approx_percentile` is randomized and gave a different
answer on every run (see `before/report_22_promo_lift_run*.tsv`), so there is no single value to match. The
converted report is deterministic and returns the lower of the two middle order values for each promo; the recon
query shows both middle values so the reader can judge it.
