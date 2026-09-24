#!/usr/bin/env python3
"""Stage 2 recon: run recon/01,02,03 from branch demo-ops on Databricks and apply the
green criteria (5 equal counts, avg_mismatch_rows = 0, four EXCEPT diffs = 0).
Exits nonzero on any mismatch. Run from anywhere inside the repo checkout."""
import subprocess, sys, os
from dbx_query import fetch

RECON_FILES = ["recon/01_row_counts.sql", "recon/02_aggregates.sql", "recon/03_row_diffs.sql"]
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def recon_sql(path):
    return subprocess.check_output(["git", "-C", REPO, "show", f"origin/demo-ops:{path}"], text=True)

def statements(text):
    body = "\n".join(l for l in text.splitlines() if not l.strip().startswith("--"))
    return [s.strip() for s in body.split(";") if s.strip()]

failures = []
rows = []
for f in RECON_FILES:
    for stmt in statements(recon_sql(f)):
        cols, data = fetch(stmt)
        print("\t".join(cols))
        for r in data:
            print("\t".join("" if v is None else str(v) for v in r))
            rec = dict(zip(cols, r))
            if "src_rows" in rec and rec["src_rows"] != rec["tgt_rows"]:
                failures.append(f"{rec['tbl']}: {rec['src_rows']} vs {rec['tgt_rows']}")
            if "src_sum" in rec and rec["src_sum"] != rec["tgt_sum"]:
                failures.append(f"{rec['metric']}: {rec['src_sum']} vs {rec['tgt_sum']}")
            if "avg_mismatch_rows" in rec and int(rec["avg_mismatch_rows"]) != 0:
                failures.append(f"avg_mismatch_rows = {rec['avg_mismatch_rows']}")
            if "rows_" in rec and int(rec["rows_"]) != 0:
                failures.append(f"{rec['side']} = {rec['rows_']}")
        print("---")

if failures:
    print("RECON FAILED:\n  " + "\n  ".join(failures))
    sys.exit(1)
print("RECON GREEN: counts equal for all 5 tables, avg_mismatch_rows = 0, all four EXCEPT diffs = 0")
