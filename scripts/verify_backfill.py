#!/usr/bin/env python3
"""Reconcile migration_demo.core Delta tables against live Redshift.

Runs identical row-count / aggregate / timestamp checks on both sides and
prints a side-by-side markdown table. Exits nonzero on any mismatch.

Requires: AWS_DEMO_ACCESS_KEY_ID, AWS_DEMO_SECRET_ACCESS_KEY,
          DATABRICKS_DEMO_HOST, DATABRICKS_DEMO_TOKEN.
"""
import json
import os
import sys
import time
import urllib.request

import boto3

WAREHOUSE_ID = "565cd2fd713738c4"

CHECKS = [
    ("customers row_count", "SELECT COUNT(*) FROM {cat}core.customers"),
    ("customers min signup_date", "SELECT CAST(MIN(signup_date) AS VARCHAR(10)) FROM {cat}core.customers"),
    ("customers max created_at", "SELECT CAST(MAX(created_at) AS VARCHAR(19)) FROM {cat}core.customers"),
    ("orders row_count", "SELECT COUNT(*) FROM {cat}core.orders"),
    ("orders sum order_total", "SELECT CAST(SUM(order_total) AS DECIMAL(18,2)) FROM {cat}core.orders"),
    ("orders avg order_total", "SELECT CAST(ROUND(AVG(order_total), 2) AS DECIMAL(18,2)) FROM {cat}core.orders"),
    ("orders min order_ts", "SELECT CAST(MIN(order_ts) AS VARCHAR(19)) FROM {cat}core.orders"),
    ("orders max order_ts", "SELECT CAST(MAX(order_ts) AS VARCHAR(19)) FROM {cat}core.orders"),
    ("order_items row_count", "SELECT COUNT(*) FROM {cat}core.order_items"),
    ("order_items sum quantity", "SELECT SUM(quantity) FROM {cat}core.order_items"),
    ("order_items sum gross", "SELECT CAST(SUM(unit_price * quantity) AS DECIMAL(18,2)) FROM {cat}core.order_items"),
]


def redshift_scalar(client, sql):
    r = client.execute_statement(WorkgroupName="demo-wg", Database="demo", Sql=sql)
    sid = r["Id"]
    while True:
        d = client.describe_statement(Id=sid)
        if d["Status"] in ("FINISHED", "FAILED", "ABORTED"):
            break
        time.sleep(1)
    if d["Status"] != "FINISHED":
        raise RuntimeError(d.get("Error"))
    res = client.get_statement_result(Id=sid)
    cell = res["Records"][0][0]
    return str(list(cell.values())[0])


def databricks_scalar(host, token, sql):
    def api(path, data=None):
        req = urllib.request.Request(
            host + path,
            data=json.dumps(data).encode() if data is not None else None,
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
            method="POST" if data is not None else "GET",
        )
        with urllib.request.urlopen(req) as resp:
            return json.load(resp)

    r = api("/api/2.0/sql/statements", {
        "statement": sql, "warehouse_id": WAREHOUSE_ID,
        "wait_timeout": "30s", "on_wait_timeout": "CONTINUE",
    })
    while r["status"]["state"] in ("PENDING", "RUNNING"):
        time.sleep(2)
        r = api(f"/api/2.0/sql/statements/{r['statement_id']}")
    if r["status"]["state"] != "SUCCEEDED":
        raise RuntimeError(r["status"].get("error"))
    return str(r["result"]["data_array"][0][0])


def normalize(v):
    return v.replace("T", " ").replace(".000Z", "").replace("Z", "").strip()


def main():
    rs = boto3.client(
        "redshift-data",
        region_name="us-east-1",
        aws_access_key_id=os.environ["AWS_DEMO_ACCESS_KEY_ID"],
        aws_secret_access_key=os.environ["AWS_DEMO_SECRET_ACCESS_KEY"],
    )
    host = os.environ["DATABRICKS_DEMO_HOST"].rstrip("/")
    token = os.environ["DATABRICKS_DEMO_TOKEN"]

    failures = 0
    print("| Check | Redshift | Databricks | Match |")
    print("|-------|----------|------------|-------|")
    for name, tmpl in CHECKS:
        rv = normalize(redshift_scalar(rs, tmpl.format(cat="")))
        dv = normalize(databricks_scalar(host, token, tmpl.format(cat="migration_demo.")))
        ok = rv == dv
        failures += 0 if ok else 1
        print(f"| {name} | {rv} | {dv} | {'yes' if ok else 'NO'} |")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
