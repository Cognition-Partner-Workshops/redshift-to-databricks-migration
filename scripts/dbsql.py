#!/usr/bin/env python3
"""Minimal Redshift Data API + Databricks Statement Execution API helpers.

Both return rows as lists of strings so results can be compared side by side.

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
RS_WORKGROUP = "demo-wg"
RS_DATABASE = "demo"
RS_REGION = "us-east-1"


def redshift_client():
    return boto3.client(
        "redshift-data",
        region_name=RS_REGION,
        aws_access_key_id=os.environ["AWS_DEMO_ACCESS_KEY_ID"],
        aws_secret_access_key=os.environ["AWS_DEMO_SECRET_ACCESS_KEY"],
    )


def redshift_query(client, sql):
    r = client.execute_statement(WorkgroupName=RS_WORKGROUP, Database=RS_DATABASE, Sql=sql)
    sid = r["Id"]
    while True:
        d = client.describe_statement(Id=sid)
        if d["Status"] in ("FINISHED", "FAILED", "ABORTED"):
            break
        time.sleep(1)
    if d["Status"] != "FINISHED":
        raise RuntimeError(f"Redshift statement failed: {d.get('Error')}")
    if not d.get("HasResultSet"):
        return []
    res = client.get_statement_result(Id=sid)
    rows = []
    for rec in res["Records"]:
        rows.append(["" if "isNull" in c else str(list(c.values())[0]) for c in rec])
    return rows


def _dbx_api(path, data=None):
    host = os.environ["DATABRICKS_DEMO_HOST"].rstrip("/")
    token = os.environ["DATABRICKS_DEMO_TOKEN"]
    req = urllib.request.Request(
        host + path,
        data=json.dumps(data).encode() if data is not None else None,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        method="POST" if data is not None else "GET",
    )
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)


def databricks_query(sql):
    r = _dbx_api("/api/2.0/sql/statements", {
        "statement": sql,
        "warehouse_id": WAREHOUSE_ID,
        "wait_timeout": "50s",
        "on_wait_timeout": "CONTINUE",
    })
    while r["status"]["state"] in ("PENDING", "RUNNING"):
        time.sleep(2)
        r = _dbx_api(f"/api/2.0/sql/statements/{r['statement_id']}")
    if r["status"]["state"] != "SUCCEEDED":
        raise RuntimeError(f"Databricks statement failed: {r['status'].get('error')}")
    data = r.get("result", {}).get("data_array", []) or []
    return [["" if v is None else str(v) for v in row] for row in data]


if __name__ == "__main__":
    target, sql = sys.argv[1], sys.argv[2]
    if os.path.isfile(sql):
        sql = open(sql).read()
    rows = redshift_query(redshift_client(), sql) if target == "rs" else databricks_query(sql)
    for row in rows:
        print("\t".join(row))
