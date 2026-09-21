#!/usr/bin/env python3
"""Run one or more .sql files (or a literal SQL string) on the existing Databricks SQL warehouse
through the Statement Execution API.

    python3 databricks/run_sql.py databricks/etl/10_build_daily_revenue.sql [more files...]
    python3 databricks/run_sql.py "SELECT count(*) FROM trino_migration_demo.core.orders"

Env: DATABRICKS_DEMO_HOST, DATABRICKS_DEMO_TOKEN. Optional DATABRICKS_WAREHOUSE_ID (defaults to the shared demo warehouse).
Statements are split on ';' after stripping '--' comments, so comments may contain semicolons.
Results print as TSV with a header; '--- <n> rows' after each statement.
"""
import os
import re
import sys
import time

import requests

HOST = os.environ["DATABRICKS_DEMO_HOST"].rstrip("/")
TOKEN = os.environ["DATABRICKS_DEMO_TOKEN"]
WAREHOUSE = os.environ.get("DATABRICKS_WAREHOUSE_ID", "565cd2fd713738c4")
HEADERS = {"Authorization": f"Bearer {TOKEN}"}


def statements(text: str):
    text = re.sub(r"--[^\n]*", "", text)
    return [s.strip() for s in text.split(";") if s.strip()]


def run(sql: str):
    r = requests.post(
        f"{HOST}/api/2.0/sql/statements",
        headers=HEADERS,
        json={"warehouse_id": WAREHOUSE, "statement": sql, "wait_timeout": "50s", "disposition": "INLINE", "format": "JSON_ARRAY"},
        timeout=120,
    )
    r.raise_for_status()
    d = r.json()
    sid = d["statement_id"]
    while d["status"]["state"] in ("PENDING", "RUNNING"):
        time.sleep(2)
        d = requests.get(f"{HOST}/api/2.0/sql/statements/{sid}", headers=HEADERS, timeout=120).json()
    if d["status"]["state"] != "SUCCEEDED":
        sys.stderr.write(f"FAILED: {d['status']}\n{sql}\n")
        sys.exit(1)
    cols = [c["name"] for c in d.get("manifest", {}).get("schema", {}).get("columns", [])]
    rows = d.get("result", {}).get("data_array", []) or []
    if cols:
        print("\t".join(cols))
    for row in rows:
        print("\t".join("NULL" if v is None else str(v) for v in row))
    print(f"--- {len(rows)} rows")


if __name__ == "__main__":
    for arg in sys.argv[1:]:
        text = open(arg).read() if os.path.exists(arg) else arg
        for s in statements(text):
            run(s)
