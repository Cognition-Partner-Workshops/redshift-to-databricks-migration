#!/usr/bin/env python3
"""Run one or more .sql files (or a literal SQL string) on the existing Databricks SQL warehouse
through the Statement Execution API.

    python3 databricks/run_sql.py databricks/etl/10_build_daily_revenue.sql [more files...]
    python3 databricks/run_sql.py "SELECT count(*) FROM trino_migration_demo.core.orders"

Env: DATABRICKS_DEMO_HOST, DATABRICKS_DEMO_TOKEN. Optional DATABRICKS_WAREHOUSE_ID (defaults to the shared demo warehouse).
Statements are split on ';' outside single-quoted strings ('' escape), backtick identifiers,
and '--' / '/* */' comments; comments are dropped, quoted text kept verbatim.
Results print as TSV with a header; '--- <n> rows' after each statement.
"""
import os
import sys
import time

import requests

HOST = os.environ["DATABRICKS_DEMO_HOST"].rstrip("/")
TOKEN = os.environ["DATABRICKS_DEMO_TOKEN"]
WAREHOUSE = os.environ.get("DATABRICKS_WAREHOUSE_ID", "565cd2fd713738c4")
HEADERS = {"Authorization": f"Bearer {TOKEN}"}


def statements(text: str):
    out, cur = [], []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == "'":
            cur.append(c)
            i += 1
            while i < n:
                cur.append(text[i])
                if text[i] == "'":
                    if i + 1 < n and text[i + 1] == "'":
                        cur.append("'")
                        i += 2
                        continue
                    i += 1
                    break
                i += 1
        elif c == "`":
            cur.append(c)
            i += 1
            while i < n:
                cur.append(text[i])
                i += 1
                if text[i - 1] == "`":
                    break
        elif c == "-" and i + 1 < n and text[i + 1] == "-":
            while i < n and text[i] != "\n":
                i += 1
        elif c == "/" and i + 1 < n and text[i + 1] == "*":
            cur.append(" ")
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i += 2
        elif c == ";":
            s = "".join(cur).strip()
            if s:
                out.append(s)
            cur = []
            i += 1
        else:
            cur.append(c)
            i += 1
    s = "".join(cur).strip()
    if s:
        out.append(s)
    return out


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
    if cols:
        print("\t".join(cols))
    result = d.get("result", {})
    total = 0
    while True:
        rows = result.get("data_array", []) or []
        for row in rows:
            print("\t".join("NULL" if v is None else str(v) for v in row))
        total += len(rows)
        link = result.get("next_chunk_internal_link")
        if not link:
            break
        result = requests.get(f"{HOST}{link}", headers=HEADERS, timeout=120)
        result.raise_for_status()
        result = result.json()
    print(f"--- {total} rows")


if __name__ == "__main__":
    for arg in sys.argv[1:]:
        text = open(arg).read() if os.path.exists(arg) else arg
        for s in statements(text):
            run(s)
