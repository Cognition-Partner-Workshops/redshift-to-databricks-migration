"""Compare the core backfill in Databricks against live Redshift.

Runs the same metrics on both sides (Redshift: SELECT only) and prints a
markdown table. Exit code 1 if any check that must match does not.

Env: REDSHIFT_DEMO_ADMIN_PASSWORD, DATABRICKS_DEMO_HOST, DATABRICKS_DEMO_TOKEN.
"""
import json
import os
import sys
import time
import urllib.request
from decimal import Decimal, InvalidOperation

import redshift_connector

REDSHIFT_HOST = "demo-wg.599083837640.us-east-1.redshift-serverless.amazonaws.com"
WAREHOUSE_ID = "565cd2fd713738c4"
RS_TS = "TO_CHAR({c}, 'YYYY-MM-DD HH24:MI:SS.US')"
DBX_TS = "date_format({c}, 'yyyy-MM-dd HH:mm:ss.SSSSSS')"
RS_DATE = "TO_CHAR({c}, 'YYYY-MM-DD')"
DBX_DATE = "date_format({c}, 'yyyy-MM-dd')"

# (table, metric, redshift expr, databricks expr, must_match)
CHECKS = [
    ("customers", "row count", "COUNT(*)", None, True),
    ("customers", "distinct customer_id", "COUNT(DISTINCT customer_id)", None, True),
    ("customers", "min / max customer_id", "MIN(customer_id) || ' / ' || MAX(customer_id)",
     "concat(MIN(customer_id), ' / ', MAX(customer_id))", True),
    ("customers", "active customers", "SUM(CASE WHEN is_active THEN 1 ELSE 0 END)", None, True),
    ("customers", "min signup_date", RS_DATE.format(c="MIN(signup_date)"), DBX_DATE.format(c="MIN(signup_date)"), True),
    ("customers", "max signup_date", RS_DATE.format(c="MAX(signup_date)"), DBX_DATE.format(c="MAX(signup_date)"), True),
    ("customers", "min created_at", RS_TS.format(c="MIN(created_at)"), DBX_TS.format(c="MIN(created_at)"), True),
    ("customers", "max created_at", RS_TS.format(c="MAX(created_at)"), DBX_TS.format(c="MAX(created_at)"), True),
    ("orders", "row count", "COUNT(*)", None, True),
    ("orders", "distinct order_id", "COUNT(DISTINCT order_id)", None, True),
    ("orders", "SUM(order_total)", "SUM(order_total)", None, True),
    ("orders", "AVG(order_total), to the cent", "ROUND(SUM(order_total) / COUNT(*), 2)", None, True),
    ("orders", "AVG(order_total), native", "AVG(order_total)", None, False),
    ("orders", "SUM(order_total) excl. cancelled", "SUM(CASE WHEN RTRIM(order_status) <> 'CANCELLED' THEN order_total END)",
     "SUM(CASE WHEN rtrim(order_status) <> 'CANCELLED' THEN order_total END)", True),
    ("orders", "min order_ts", RS_TS.format(c="MIN(order_ts)"), DBX_TS.format(c="MIN(order_ts)"), True),
    ("orders", "max order_ts", RS_TS.format(c="MAX(order_ts)"), DBX_TS.format(c="MAX(order_ts)"), True),
    ("orders", "min loaded_at", RS_TS.format(c="MIN(loaded_at)"), DBX_TS.format(c="MIN(loaded_at)"), True),
    ("orders", "max loaded_at", RS_TS.format(c="MAX(loaded_at)"), DBX_TS.format(c="MAX(loaded_at)"), True),
    ("order_items", "row count", "COUNT(*)", None, True),
    ("order_items", "distinct order_item_id", "COUNT(DISTINCT order_item_id)", None, True),
    ("order_items", "distinct order_id", "COUNT(DISTINCT order_id)", None, True),
    ("order_items", "SUM(quantity)", "SUM(quantity)", None, True),
    ("order_items", "SUM(quantity * unit_price)", "SUM(quantity * unit_price)", None, True),
    ("order_items", "SUM(discount_pct)", "SUM(discount_pct)", None, True),
]


def redshift_rows(table, exprs):
    conn = redshift_connector.connect(host=REDSHIFT_HOST, port=5439, database="demo", user="demoadmin",
                                      password=os.environ["REDSHIFT_DEMO_ADMIN_PASSWORD"])
    try:
        cur = conn.cursor()
        cur.execute(f"SELECT {', '.join(exprs)} FROM core.{table}")
        return [None if v is None else str(v) for v in cur.fetchone()]
    finally:
        conn.close()


def databricks_rows(table, exprs):
    host = os.environ["DATABRICKS_DEMO_HOST"].removeprefix("https://").rstrip("/")
    hdr = {"Authorization": "Bearer " + os.environ["DATABRICKS_DEMO_TOKEN"], "Content-Type": "application/json"}
    body = json.dumps({"warehouse_id": WAREHOUSE_ID, "wait_timeout": "50s", "on_wait_timeout": "CONTINUE",
                       "statement": f"SELECT {', '.join(exprs)} FROM migration_demo.core.{table}"}).encode()
    d = json.load(urllib.request.urlopen(urllib.request.Request(
        f"https://{host}/api/2.0/sql/statements", data=body, headers=hdr)))
    while d["status"]["state"] in ("PENDING", "RUNNING"):
        time.sleep(1)
        d = json.load(urllib.request.urlopen(urllib.request.Request(
            f"https://{host}/api/2.0/sql/statements/{d['statement_id']}", headers=hdr)))
    if d["status"]["state"] != "SUCCEEDED":
        raise RuntimeError(d["status"].get("error"))
    return d["result"]["data_array"][0]


def same(a, b):
    try:
        return Decimal(a) == Decimal(b)
    except (InvalidOperation, TypeError):
        return a == b


def main():
    results = []
    for table in dict.fromkeys(t for t, *_ in CHECKS):
        checks = [c for c in CHECKS if c[0] == table]
        rs = redshift_rows(table, [c[2] for c in checks])
        dbx = databricks_rows(table, [c[3] or c[2] for c in checks])
        results += [(c, r, d) for c, r, d in zip(checks, rs, dbx)]

    failed = False
    print("| Table | Check | Redshift | Databricks | Result |")
    print("|---|---|---|---|---|")
    for (table, metric, _, _, must_match), r, d in results:
        ok = same(r, d)
        failed |= must_match and not ok
        verdict = "match" if ok else ("MISMATCH" if must_match else "differs (expected, see note)")
        print(f"| {table} | {metric} | {r} | {d} | {verdict} |")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
