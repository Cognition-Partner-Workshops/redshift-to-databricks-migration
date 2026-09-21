# Report 22 exact reconciliation

The Databricks converted query uses `percentile(order_total, 0.5)` cast to
`FLOAT`, a two-decimal cast for the average, and null-safe ordering. The
Trino comparison is read-only and computes the exact median from sorted
values, averaging the two middle values for even populations.

| promo | Databricks median | Trino median | Databricks average | Trino average | rank |
|---|---:|---:|---:|---:|---:|
| NONE | 350.26 | 350.26 | 350.26 | 350.26 | 1 |
| LOYALTY5 | 350.13 | 350.13 | 350.13 | 350.13 | 2 |
| SPRING15 | 350.00 | 350.0 | 350.00 | 350.00 | 3 |
| WELCOME10 | 349.87 | 349.87 | 349.87 | 349.87 | 4 |

Values match by promo and ranking matches by promo. Evidence:

- `docs/evidence/run-2/dbx_report_22_exact.tsv`
- `docs/evidence/run-2/trino_report_22_exact.sql`
- `docs/evidence/run-2/trino_report_22_exact.csv`
