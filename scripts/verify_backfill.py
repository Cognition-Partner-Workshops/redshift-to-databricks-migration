#!/usr/bin/env python3
"""Reconcile migration_demo.core Delta tables against live Redshift.

One multi-metric aggregate statement per table is run on each side (row count,
distinct keys, sums/averages to the cent, null counts, min/max timestamps) and
the results are printed as a side-by-side markdown table. Exits nonzero on any
mismatch.

Run from this directory: python3 verify_backfill.py
"""
import sys

import dbsql

# (table, [(metric, expression)]) -- expressions are dialect-neutral.
TABLES = [
    ("customers", [
        ("row_count", "COUNT(*)"),
        ("distinct customer_id", "COUNT(DISTINCT customer_id)"),
        ("null email", "SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END)"),
        ("active customers", "SUM(CASE WHEN is_active THEN 1 ELSE 0 END)"),
        ("distinct region", "COUNT(DISTINCT region)"),
        ("min signup_date", "CAST(MIN(signup_date) AS VARCHAR(10))"),
        ("max signup_date", "CAST(MAX(signup_date) AS VARCHAR(10))"),
        ("max created_at", "CAST(MAX(created_at) AS VARCHAR(19))"),
    ]),
    ("orders", [
        ("row_count", "COUNT(*)"),
        ("distinct order_id", "COUNT(DISTINCT order_id)"),
        ("distinct customer_id", "COUNT(DISTINCT customer_id)"),
        ("sum order_total", "CAST(SUM(order_total) AS DECIMAL(18,2))"),
        # AVG(DECIMAL) result scale differs by engine (Redshift keeps the input
        # scale, Databricks widens); compute with an explicit precision instead.
        ("avg order_total (4dp)", "CAST(ROUND(CAST(SUM(order_total) AS DECIMAL(24,6)) / COUNT(*), 4) AS DECIMAL(18,4))"),
        ("cancelled orders", "SUM(CASE WHEN TRIM(order_status) = 'CANCELLED' THEN 1 ELSE 0 END)"),
        ("min order_ts", "CAST(MIN(order_ts) AS VARCHAR(19))"),
        ("max order_ts", "CAST(MAX(order_ts) AS VARCHAR(19))"),
        ("max loaded_at", "CAST(MAX(loaded_at) AS VARCHAR(19))"),
    ]),
    ("order_items", [
        ("row_count", "COUNT(*)"),
        ("distinct order_item_id", "COUNT(DISTINCT order_item_id)"),
        ("distinct order_id", "COUNT(DISTINCT order_id)"),
        ("sum quantity", "SUM(quantity)"),
        ("sum gross (qty*price)", "CAST(SUM(quantity * unit_price) AS DECIMAL(18,2))"),
        ("sum discount_pct", "CAST(SUM(discount_pct) AS DECIMAL(18,4))"),
        ("min order_id", "MIN(order_id)"),
        ("max order_id", "MAX(order_id)"),
    ]),
]


def normalize(v):
    return v.replace("T", " ").replace(".000Z", "").replace("Z", "").strip()


def main():
    rs = dbsql.redshift_client()
    failures = 0
    print("| Table | Check | Redshift | Databricks | Match |")
    print("|-------|-------|----------|------------|-------|")
    for table, checks in TABLES:
        select = ", ".join(expr for _, expr in checks)
        rs_row = dbsql.redshift_query(rs, f"SELECT {select} FROM core.{table}")[0]
        dbx_row = dbsql.databricks_query(f"SELECT {select} FROM migration_demo.core.{table}")[0]
        for (name, _), rv, dv in zip(checks, rs_row, dbx_row):
            rv, dv = normalize(rv), normalize(dv)
            ok = rv == dv
            failures += 0 if ok else 1
            print(f"| {table} | {name} | {rv} | {dv} | {'yes' if ok else 'NO'} |")
    print()
    print("RESULT:", "PASS" if failures == 0 else f"FAIL ({failures} mismatch(es))")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
