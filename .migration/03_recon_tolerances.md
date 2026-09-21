# Reconciliation tolerances

- Match mode is exact.
- Numeric and aggregate tolerances are zero.
- Population is all rows. Both marts are below
  `full_diff_row_threshold`.
- `decimal_round` uses two places only on recomputed AVG or ratio columns,
  such as `avg_order_value`; stored DECIMAL columns use identity.
- Marts run in DEGRADED mode because their source side is the run-1 Trino
  snapshot in `trino_src`, not a live Trino adapter.
- The authored JSON values are authoritative.
