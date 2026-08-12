#!/usr/bin/env python3
"""Run a SQL statement on Databricks via the Statement Execution API."""
import json
import os
import sys
import time

import requests

HOST = os.environ["DATABRICKS_DEMO_HOST"].rstrip("/")
TOKEN = os.environ["DATABRICKS_DEMO_TOKEN"]
WAREHOUSE_ID = os.environ.get("DATABRICKS_WAREHOUSE_ID", "565cd2fd713738c4")
HEADERS = {"Authorization": f"Bearer {TOKEN}"}


def run_sql(sql: str):
    r = requests.post(
        f"{HOST}/api/2.0/sql/statements",
        headers=HEADERS,
        json={"statement": sql, "warehouse_id": WAREHOUSE_ID, "wait_timeout": "30s"},
    )
    r.raise_for_status()
    data = r.json()
    while data["status"]["state"] in ("PENDING", "RUNNING"):
        time.sleep(2)
        sid = data["statement_id"]
        data = requests.get(f"{HOST}/api/2.0/sql/statements/{sid}", headers=HEADERS).json()
    if data["status"]["state"] != "SUCCEEDED":
        raise RuntimeError(json.dumps(data["status"], indent=2))
    return data.get("result", {}).get("data_array", [])


if __name__ == "__main__":
    for row in run_sql(sys.argv[1]):
        print("\t".join("" if v is None else str(v) for v in row))
