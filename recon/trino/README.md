# Trino reconciliation queries

- `01_row_counts.sql` checks row counts for the six snapshot and converted objects.
- `02_aggregates.sql` checks mart row counts, totals, AOV sums, and date ranges.
- `03_row_diffs.sql` checks symmetric row differences and raw AOV mismatches.

The green criteria are equal counts on all six objects, zero for both
`EXCEPT` counts, and zero for both `aov mismatch (raw)` counts.
