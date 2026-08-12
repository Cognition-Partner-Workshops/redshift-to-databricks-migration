#!/usr/bin/env python3
"""Verify the Databricks backfill of migration_demo.core against live Redshift.

Runs identical row-count / SUM / AVG / MIN / MAX checks on both sides and
prints a markdown comparison table. Redshift is live, so both sides are
queried back-to-back as a single point-in-time snapshot; a mismatch usually
means new data landed between the backfill and the check — re-run the CTAS.

Env:
    REDSHIFT_DEMO_ADMIN_PASSWORD (psql as demoadmin against the live endpoint)
    DATABRICKS_DEMO_HOST / DATABRICKS_DEMO_TOKEN
"""
import os
import subprocess
import time

import requests

REDSHIFT_HOST = "demo-wg.599083837640.us-east-1.redshift-serverless.amazonaws.com"
DATABASE = "demo"
WAREHOUSE_ID = "565cd2fd713738c4"
DBX_HOST = os.environ["DATABRICKS_DEMO_HOST"].rstrip("/")
DBX_HEADERS = {"Authorization": "Bearer " + os.environ["DATABRICKS_DEMO_TOKEN"]}

CHECKS = [
    ("customers row count", "SELECT COUNT(*) FROM {p}customers"),
    ("orders row count", "SELECT COUNT(*) FROM {p}orders"),
    ("order_items row count", "SELECT COUNT(*) FROM {p}order_items"),
    ("SUM(order_total)", "SELECT CAST(SUM(order_total) AS DECIMAL(20,2)) FROM {p}orders"),
    # Explicit truncation on both sides: Redshift truncates native decimal AVG
    # while Databricks rounds, so a raw AVG comparison diverges by a cent even
    # on identical data. SUM/COUNT with FLOOR is engine-neutral.
    ("AVG(order_total) truncated to cent",
     "SELECT CAST(FLOOR(SUM(order_total) * 100 / COUNT(*)) / 100 AS DECIMAL(20,2)) FROM {p}orders"),
    ("MIN(order_ts)", "SELECT CAST(MIN(order_ts) AS VARCHAR(32)) FROM {p}orders"),
    ("MAX(order_ts)", "SELECT CAST(MAX(order_ts) AS VARCHAR(32)) FROM {p}orders"),
    ("MIN(customers.created_at)", "SELECT CAST(MIN(created_at) AS VARCHAR(32)) FROM {p}customers"),
    ("MAX(customers.created_at)", "SELECT CAST(MAX(created_at) AS VARCHAR(32)) FROM {p}customers"),
]


def redshift_scalar(sql):
    env = dict(os.environ, PGPASSWORD=os.environ["REDSHIFT_DEMO_ADMIN_PASSWORD"])
    out = subprocess.run(
        ["psql", "-h", REDSHIFT_HOST, "-p", "5439", "-U", "demoadmin",
         "-d", DATABASE, "-tA", "-c", sql],
        env=env, capture_output=True, text=True, check=True)
    return out.stdout.strip()


def dbx_scalar(sql):
    d = requests.post(f"{DBX_HOST}/api/2.0/sql/statements", headers=DBX_HEADERS, json={
        "statement": sql, "warehouse_id": WAREHOUSE_ID, "wait_timeout": "30s"}).json()
    while d.get("status", {}).get("state") in ("PENDING", "RUNNING"):
        time.sleep(1)
        d = requests.get(f"{DBX_HOST}/api/2.0/sql/statements/{d['statement_id']}",
                         headers=DBX_HEADERS).json()
    if d["status"]["state"] != "SUCCEEDED":
        raise RuntimeError(d["status"])
    return str(d["result"]["data_array"][0][0])


def norm(v):
    return v.replace("T", " ").rstrip("Z")[:19] if "-" in v and ":" in v else v


def main():
    print(f"Snapshot taken at (UTC): {time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime())}")
    print()
    print("| Check | Redshift (live) | Databricks (migration_demo.core) | Match |")
    print("|---|---|---|---|")
    all_ok = True
    for name, tmpl in CHECKS:
        r_val = redshift_scalar(tmpl.format(p="core."))
        d_val = dbx_scalar(tmpl.format(p="migration_demo.core."))
        ok = norm(r_val) == norm(d_val)
        all_ok &= ok
        print(f"| {name} | {r_val} | {d_val} | {'yes' if ok else 'NO'} |")
    print()
    print("All checks passed." if all_ok else "MISMATCH detected — re-run backfill CTAS.")
    return 0 if all_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
