"""Reconcile migration_demo.core.* (Databricks) against live Redshift core.*.

Env: AWS_DEMO_ACCESS_KEY_ID, AWS_DEMO_SECRET_ACCESS_KEY (Redshift Data API),
     DATABRICKS_DEMO_HOST, DATABRICKS_DEMO_TOKEN.
Usage: python scripts/verify_backfill.py   (exit 1 on any mismatch)
"""
import json
import os
import sys
import time

import boto3
import requests

REGION = "us-east-1"
WORKGROUP = "demo-wg"
DATABASE = "demo"
WAREHOUSE_ID = "565cd2fd713738c4"
TARGET_SCHEMA = "migration_demo.core"

CHECKS = {
    "customers": (
        "SELECT COUNT(*) AS row_count, COUNT(DISTINCT customer_id) AS distinct_keys,"
        " SUM(CASE WHEN is_active THEN 1 ELSE 0 END) AS active_customers,"
        " COUNT(DISTINCT region) AS regions,"
        " CAST(MIN(signup_date) AS VARCHAR(64)) AS min_signup, CAST(MAX(signup_date) AS VARCHAR(64)) AS max_signup,"
        " CAST(MIN(created_at) AS VARCHAR(64)) AS min_created, CAST(MAX(created_at) AS VARCHAR(64)) AS max_created"
        " FROM {s}.customers"
    ),
    "orders": (
        "SELECT COUNT(*) AS row_count, COUNT(DISTINCT order_id) AS distinct_keys,"
        " CAST(SUM(order_total) AS VARCHAR(64)) AS sum_order_total,"
        " SUM(CASE WHEN TRIM(order_status)='CANCELLED' THEN 1 ELSE 0 END) AS cancelled,"
        " CAST(MIN(order_ts) AS VARCHAR(64)) AS min_order_ts, CAST(MAX(order_ts) AS VARCHAR(64)) AS max_order_ts,"
        " CAST(MIN(loaded_at) AS VARCHAR(64)) AS min_loaded, CAST(MAX(loaded_at) AS VARCHAR(64)) AS max_loaded"
        " FROM {s}.orders"
    ),
    "order_items": (
        "SELECT COUNT(*) AS row_count, COUNT(DISTINCT order_item_id) AS distinct_keys,"
        " SUM(quantity) AS sum_qty, CAST(SUM(unit_price) AS VARCHAR(64)) AS sum_unit_price,"
        " CAST(SUM(quantity*unit_price*(1-discount_pct)) AS VARCHAR(64)) AS sum_net,"
        " MIN(order_id) AS min_order_id, MAX(order_id) AS max_order_id"
        " FROM {s}.order_items"
    ),
}


def redshift(sql):
    client = boto3.client(
        "redshift-data",
        region_name=REGION,
        aws_access_key_id=os.environ["AWS_DEMO_ACCESS_KEY_ID"],
        aws_secret_access_key=os.environ["AWS_DEMO_SECRET_ACCESS_KEY"],
    )
    sid = client.execute_statement(WorkgroupName=WORKGROUP, Database=DATABASE, Sql=sql)["Id"]
    while True:
        desc = client.describe_statement(Id=sid)
        if desc["Status"] in ("FINISHED", "FAILED", "ABORTED"):
            break
        time.sleep(0.5)
    if desc["Status"] != "FINISHED":
        raise RuntimeError(f"Redshift statement failed: {desc.get('Error')}")
    res = client.get_statement_result(Id=sid)
    cols = [c["name"] for c in res["ColumnMetadata"]]
    rec = res["Records"][0]
    return {k: list(v.values())[0] for k, v in zip(cols, rec)}


def databricks(sql):
    host = os.environ["DATABRICKS_DEMO_HOST"].rstrip("/")
    if not host.startswith("http"):
        host = "https://" + host
    hdr = {"Authorization": f"Bearer {os.environ['DATABRICKS_DEMO_TOKEN']}"}
    r = requests.post(
        f"{host}/api/2.0/sql/statements",
        headers=hdr,
        json={"warehouse_id": WAREHOUSE_ID, "statement": sql, "wait_timeout": "50s",
              "disposition": "INLINE", "format": "JSON_ARRAY"},
    ).json()
    while r.get("status", {}).get("state") in ("PENDING", "RUNNING"):
        time.sleep(1)
        r = requests.get(f"{host}/api/2.0/sql/statements/{r['statement_id']}", headers=hdr).json()
    if r.get("status", {}).get("state") != "SUCCEEDED":
        raise RuntimeError(f"Databricks statement failed: {json.dumps(r.get('status'))}")
    cols = [c["name"] for c in r["manifest"]["schema"]["columns"]]
    return dict(zip(cols, r["result"]["data_array"][0]))


def main():
    mismatches = 0
    print("| Table | Check | Redshift | Databricks | Match |")
    print("|---|---|---|---|---|")
    for table, query in CHECKS.items():
        src = redshift(query.format(s="core"))
        tgt = databricks(query.format(s=TARGET_SCHEMA))
        for key in src:
            a, b = str(src[key]).strip(), str(tgt[key]).strip()
            ok = a == b
            mismatches += not ok
            print(f"| core.{table} | {key} | {a} | {b} | {'yes' if ok else 'NO'} |")
    print(f"\n{mismatches} mismatch(es)")
    sys.exit(1 if mismatches else 0)


if __name__ == "__main__":
    main()
