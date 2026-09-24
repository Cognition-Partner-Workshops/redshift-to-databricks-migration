#!/usr/bin/env python3
"""Report parity: run sql/reports/20,21 on Redshift and databricks/reports/20,21 on
Databricks, strip ' 00:00:00' from Redshift TRUNC dates, and diff the TSV output.
Exits nonzero if either report differs."""
import os, sys, difflib
from rs_query import fetch as rs_fetch
from dbx_query import fetch as dbx_fetch

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPORTS = [("sql/reports/20_region_topline.sql", "databricks/reports/20_region_topline.sql"),
           ("sql/reports/21_channel_trend.sql", "databricks/reports/21_channel_trend.sql")]

def statement(path):
    text = open(os.path.join(REPO, path)).read()
    body = "\n".join(l for l in text.splitlines() if not l.strip().startswith("--"))
    return body.strip().rstrip(";")

def tsv(cols, data):
    out = ["\t".join(cols)]
    for r in data:
        out.append("\t".join("" if v is None else str(v) for v in r))
    return out

ok = True
for rs_path, dbx_path in REPORTS:
    rs = [l.replace(" 00:00:00", "") for l in tsv(*rs_fetch(statement(rs_path)))]
    dbx = tsv(*dbx_fetch(statement(dbx_path)))
    print(f"## {rs_path} vs {dbx_path}: redshift={len(rs)-1} rows, databricks={len(dbx)-1} rows")
    if rs == dbx:
        print("\n".join(dbx))
        print("PARITY OK\n")
    else:
        ok = False
        print("\n".join(difflib.unified_diff(rs, dbx, "redshift", "databricks", lineterm="")))
        print("PARITY FAILED\n")

sys.exit(0 if ok else 1)
