#!/usr/bin/env python3
"""Data-level reconciliation of the migrated marts against live Redshift.

Checks (all executed from the Databricks SQL warehouse unless noted):
  1. Row counts per mart (recon/01_row_counts.sql)
  2. Per-column aggregates to the cent (recon/02_column_aggregates.sql)
  3. Row-level EXCEPT diffs in both directions (recon/03_row_level_except.sql)
  4. Report output diffs: legacy report SQL runs on Redshift via the Data
     API, converted SQL on Databricks, and the result sets are compared row
     by row.

Redshift is live; run the recon immediately after refreshing both estates so
both sides reflect the same snapshot.

Env:
    AWS credentials + AWS_DEFAULT_REGION=us-east-1 (Redshift Data API)
    DATABRICKS_DEMO_HOST / DATABRICKS_DEMO_TOKEN

Exit code 0 iff every check is green.
"""
import os
import re
import time

import boto3
import requests

WORKGROUP = "demo-wg"
DATABASE = "demo"
WAREHOUSE_ID = "565cd2fd713738c4"
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)

rs = boto3.client("redshift-data")
DBX_HOST = os.environ["DATABRICKS_DEMO_HOST"].rstrip("/")
DBX_HEADERS = {"Authorization": "Bearer " + os.environ["DATABRICKS_DEMO_TOKEN"]}


def redshift_rows(sql):
    r = rs.execute_statement(WorkgroupName=WORKGROUP, Database=DATABASE, Sql=sql)
    sid = r["Id"]
    while True:
        d = rs.describe_statement(Id=sid)
        if d["Status"] in ("FINISHED", "FAILED", "ABORTED"):
            break
        time.sleep(0.5)
    if d["Status"] != "FINISHED":
        raise RuntimeError(d.get("Error"))
    res = rs.get_statement_result(Id=sid)
    return [tuple(None if c.get("isNull") else str(next(iter(c.values()))) for c in rec)
            for rec in res["Records"]]


def dbx_rows(sql):
    d = requests.post(f"{DBX_HOST}/api/2.0/sql/statements", headers=DBX_HEADERS, json={
        "statement": sql, "warehouse_id": WAREHOUSE_ID, "wait_timeout": "30s"}).json()
    while d.get("status", {}).get("state") in ("PENDING", "RUNNING"):
        time.sleep(1)
        d = requests.get(f"{DBX_HOST}/api/2.0/sql/statements/{d['statement_id']}",
                         headers=DBX_HEADERS).json()
    if d.get("status", {}).get("state") != "SUCCEEDED":
        raise RuntimeError(d.get("status"))
    return [tuple(None if v is None else str(v) for v in row)
            for row in d.get("result", {}).get("data_array", []) or []]


def statements(path):
    sql = open(path).read()
    sql = re.sub(r"--[^\n]*", "", sql)
    return [s.strip() for s in sql.split(";") if s.strip()]


def norm_num(v):
    if v is None:
        return None
    try:
        return f"{float(v):.4f}"
    except ValueError:
        return v.strip() if isinstance(v, str) else v


def norm_row(row):
    return tuple(norm_num(v) for v in row)


def main():
    ok = True
    print(f"Recon snapshot at (UTC): {time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime())}\n")

    print("### 1. Row counts")
    for row in dbx_rows(statements(os.path.join(HERE, "01_row_counts.sql"))[0]):
        match = row[1] == row[2]
        ok &= match
        print(f"| {row[0]} | redshift={row[1]} | databricks={row[2]} | {'yes' if match else 'NO'} |")

    print("\n### 2. Per-column aggregates (to the cent)")
    for st in statements(os.path.join(HERE, "02_column_aggregates.sql")):
        rows = dbx_rows(st)
        match = len(rows) == 2 and norm_row(rows[0][1:]) == norm_row(rows[1][1:])
        ok &= match
        for r in rows:
            print("| " + " | ".join("NULL" if v is None else v for v in r) + " |")
        print(f"-> {'match' if match else 'MISMATCH'}")

    print("\n### 3. Row-level EXCEPT diffs (must all be 0 rows)")
    labels = ["daily_revenue RS-only", "daily_revenue DBX-only",
              "customer_ltv RS-only", "customer_ltv DBX-only"]
    for label, st in zip(labels, statements(os.path.join(HERE, "03_row_level_except.sql"))):
        rows = dbx_rows(st)
        ok &= not rows
        print(f"| {label} | {len(rows)} rows | {'yes' if not rows else 'NO'} |")
        for r in rows[:5]:
            print("    ", r)

    print("\n### 4. Report output comparison (legacy on Redshift vs converted on Databricks)")
    for legacy, converted in [
        ("sql/reports/20_region_topline.sql", "databricks/reports/20_region_topline.sql"),
        ("sql/reports/21_channel_trend.sql", "databricks/reports/21_channel_trend.sql"),
    ]:
        r_rows = [norm_row(r) for r in redshift_rows(open(os.path.join(REPO, legacy)).read())]
        d_rows = [norm_row(r) for r in dbx_rows(statements(os.path.join(REPO, converted))[0])]
        match = r_rows == d_rows
        ok &= match
        print(f"| {os.path.basename(legacy)} | redshift {len(r_rows)} rows | "
              f"databricks {len(d_rows)} rows | {'identical' if match else 'DIFFERENT'} |")
        if not match:
            r_set, d_set = set(r_rows), set(d_rows)
            for r in list(r_set - d_set)[:5]:
                print("    RS only:", r)
            for r in list(d_set - r_set)[:5]:
                print("    DBX only:", r)

    print("\n" + ("RECONCILIATION GREEN." if ok else "RECONCILIATION FAILED."))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
