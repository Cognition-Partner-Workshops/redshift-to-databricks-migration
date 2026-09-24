#!/usr/bin/env python3
"""Verify migration_demo.core Delta tables against live Redshift.

Compares exact row counts, order-total aggregates (to the cent),
and min/max timestamps per table.

Requires: AWS_DEMO_ACCESS_KEY_ID / AWS_DEMO_SECRET_ACCESS_KEY (Redshift Data API),
DATABRICKS_DEMO_HOST / DATABRICKS_DEMO_TOKEN.
"""
import os
import time

import boto3

from dbsql import run_sql as dbx_sql

REGION = "us-east-1"
WORKGROUP = "demo-wg"
DATABASE = "demo"

rs = boto3.client(
    "redshift-data",
    region_name=REGION,
    aws_access_key_id=os.environ["AWS_DEMO_ACCESS_KEY_ID"],
    aws_secret_access_key=os.environ["AWS_DEMO_SECRET_ACCESS_KEY"],
)


def rs_sql(sql: str):
    sid = rs.execute_statement(WorkgroupName=WORKGROUP, Database=DATABASE, Sql=sql)["Id"]
    while True:
        d = rs.describe_statement(Id=sid)
        if d["Status"] in ("FINISHED", "FAILED", "ABORTED"):
            break
        time.sleep(1)
    if d["Status"] != "FINISHED":
        raise RuntimeError(d.get("Error", d["Status"]))
    rows = rs.get_statement_result(Id=sid)["Records"]
    return [[list(c.values())[0] for c in r] for r in rows]


CHECKS = [
    ("core.customers row count", "SELECT COUNT(*) FROM {}customers"),
    ("customers min/max created_at",
     "SELECT MIN(created_at), MAX(created_at) FROM {}customers"),
    ("core.orders row count", "SELECT COUNT(*) FROM {}orders"),
    ("orders SUM(order_total)",
     "SELECT CAST(SUM(order_total) AS DECIMAL(18,2)) FROM {}orders"),
    ("orders AVG(order_total) (cent)",
     "SELECT ROUND(SUM(CAST(order_total AS DECIMAL(18,6))) / COUNT(*), 2) FROM {}orders"),
    ("orders min/max order_ts",
     "SELECT MIN(order_ts), MAX(order_ts) FROM {}orders"),
    ("core.order_items row count", "SELECT COUNT(*) FROM {}order_items"),
    ("order_items SUM(qty*price)",
     "SELECT CAST(SUM(quantity * unit_price) AS DECIMAL(18,2)) FROM {}order_items"),
]


def norm_val(v):
    s = str(v)
    # Normalize timestamp renderings: "2026-08-11T20:44:41.000Z" -> "2026-08-11 20:44:41"
    if "T" in s and s.endswith("Z"):
        s = s.replace("T", " ").rstrip("Z")
        if s.endswith(".000"):
            s = s[:-4]
    return s


def norm(rows):
    return " / ".join(norm_val(v) for v in rows[0]) if rows else ""


def main():
    print(f"| Check | Redshift | Databricks | Match |")
    print(f"|---|---|---|---|")
    all_ok = True
    for name, tmpl in CHECKS:
        r = norm(rs_sql(tmpl.format("core.")))
        d = norm(dbx_sql(tmpl.format("migration_demo.core.")))
        ok = r == d
        all_ok &= ok
        print(f"| {name} | {r} | {d} | {'OK' if ok else 'MISMATCH'} |")
    print()
    print("RESULT:", "ALL CHECKS PASSED" if all_ok else "MISMATCHES FOUND")
    return 0 if all_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
