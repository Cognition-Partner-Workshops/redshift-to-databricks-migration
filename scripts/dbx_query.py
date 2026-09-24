#!/usr/bin/env python3
"""Databricks Statement Execution API on the shared SQL warehouse 565cd2fd713738c4
(do not create new warehouses), with chunk pagination.
CLI: dbx_query.py <file.sql|SQL>  -> TSV.   Module: fetch(sql) -> (columns, rows)."""
import os, sys, time, json, requests

HOST = os.environ["DATABRICKS_DEMO_HOST"].rstrip("/")
HEADERS = {"Authorization": f"Bearer {os.environ['DATABRICKS_DEMO_TOKEN']}"}
WAREHOUSE = "565cd2fd713738c4"

def fetch(sql):
    r = requests.post(f"{HOST}/api/2.0/sql/statements", headers=HEADERS, json={
        "warehouse_id": WAREHOUSE, "statement": sql, "wait_timeout": "50s",
        "disposition": "INLINE", "format": "JSON_ARRAY"})
    r.raise_for_status()
    d = r.json()
    sid = d["statement_id"]
    while d["status"]["state"] in ("PENDING", "RUNNING"):
        time.sleep(2)
        d = requests.get(f"{HOST}/api/2.0/sql/statements/{sid}", headers=HEADERS).json()
    if d["status"]["state"] != "SUCCEEDED":
        raise RuntimeError(json.dumps(d["status"]))
    cols = [c["name"] for c in d.get("manifest", {}).get("schema", {}).get("columns", [])]
    rows, res = [], d.get("result", {})
    while True:
        rows.extend(res.get("data_array", []) or [])
        nxt = res.get("next_chunk_internal_link")
        if not nxt:
            return cols, rows
        res = requests.get(f"{HOST}{nxt}", headers=HEADERS).json()

def statements(text):
    body = "\n".join(l for l in text.splitlines() if not l.strip().startswith("--"))
    return [s.strip() for s in body.split(";") if s.strip()]

if __name__ == "__main__":
    arg = sys.argv[1]
    text = open(arg).read() if os.path.exists(arg) else arg
    for stmt in statements(text):
        cols, rows = fetch(stmt)
        if cols:
            print("\t".join(cols))
        for r in rows:
            print("\t".join("" if v is None else str(v) for v in r))
