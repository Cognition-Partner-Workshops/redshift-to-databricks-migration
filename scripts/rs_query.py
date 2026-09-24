#!/usr/bin/env python3
"""Read-only Redshift Data API query (workgroup demo-wg, db demo) with result pagination.
CLI: rs_query.py <file.sql|SQL>  -> TSV, with ' 00:00:00' stripped from values because
Redshift TRUNC() yields timestamp-formatted dates in Data API output.
Module: fetch(sql) -> (columns, rows)."""
import os, sys, time, boto3

client = boto3.client("redshift-data", region_name="us-east-1",
                      aws_access_key_id=os.environ["AWS_DEMO_ACCESS_KEY_ID"],
                      aws_secret_access_key=os.environ["AWS_DEMO_SECRET_ACCESS_KEY"])

def fetch(sql):
    sid = client.execute_statement(WorkgroupName="demo-wg", Database="demo", Sql=sql)["Id"]
    while True:
        d = client.describe_statement(Id=sid)
        if d["Status"] in ("FINISHED", "FAILED", "ABORTED"):
            break
        time.sleep(1)
    if d["Status"] != "FINISHED":
        raise RuntimeError(d.get("Error"))
    if not d.get("HasResultSet"):
        return [], []
    cols, rows, kw = [], [], {"Id": sid}
    while True:
        res = client.get_statement_result(**kw)
        cols = cols or [m["name"] for m in res["ColumnMetadata"]]
        for rec in res["Records"]:
            rows.append([None if v.get("isNull") else list(v.values())[0] for v in rec])
        if "NextToken" not in res:
            return cols, rows
        kw["NextToken"] = res["NextToken"]

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
            print("\t".join("" if v is None else str(v).replace(" 00:00:00", "") for v in r))
