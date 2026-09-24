#!/usr/bin/env python3
"""Rebuild Redshift legacy marts as demoadmin (IAM user cannot CREATE in schema mart).
Runs sql/etl/10 and sql/etl/11 statement-by-statement, then GRANT SELECT to PUBLIC."""
import os, sys, re
import redshift_connector

REPO = os.path.expanduser("~/repos/redshift-to-databricks-migration")
FILES = ["sql/etl/10_build_daily_revenue.sql", "sql/etl/11_build_customer_ltv.sql"]

def strip_comments(text):
    return "\n".join(re.sub(r"--.*$", "", ln) for ln in text.splitlines())

conn = redshift_connector.connect(
    host="demo-wg.599083837640.us-east-1.redshift-serverless.amazonaws.com",
    port=5439, database="demo", user="demoadmin",
    password=os.environ["REDSHIFT_DEMO_ADMIN_PASSWORD"])
conn.autocommit = False
cur = conn.cursor()
try:
    for f in FILES:
        text = strip_comments(open(os.path.join(REPO, f)).read())
        for stmt in [s.strip() for s in text.split(";") if s.strip()]:
            print(f"[{f}] {stmt.splitlines()[0][:70]} ...")
            cur.execute(stmt)
    cur.execute("GRANT SELECT ON ALL TABLES IN SCHEMA mart TO PUBLIC")
    conn.commit()
    for t in ("mart.daily_revenue", "mart.customer_ltv"):
        cur.execute(f"SELECT COUNT(*) FROM {t}")
        print(t, "rows:", cur.fetchone()[0])
    print("Redshift marts rebuilt as demoadmin; GRANT applied.")
except Exception as e:
    conn.rollback()
    print("FAILED, rolled back:", e)
    sys.exit(1)
finally:
    conn.close()
