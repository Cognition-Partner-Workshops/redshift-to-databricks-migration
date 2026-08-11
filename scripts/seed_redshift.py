#!/usr/bin/env python3
"""Seed the demo Redshift Serverless warehouse via the Redshift Data API.

Creates schemas/tables from sql/ddl, generates a deterministic synthetic
e-commerce dataset (2,000 customers, ~60k orders, ~150k order items), loads it
in batched INSERTs, then runs the ETL scripts to build the marts.

Usage:
    python scripts/seed_redshift.py            # full seed
    python scripts/seed_redshift.py --verify   # counts only

Env: AWS credentials + AWS_DEFAULT_REGION; uses workgroup demo-wg / db demo.
"""
import argparse
import datetime as dt
import pathlib
import random
import time

import boto3

WORKGROUP = "demo-wg"
DATABASE = "demo"
ROOT = pathlib.Path(__file__).resolve().parents[1]
REGIONS = ["WEST", "EAST", "NRTH", "SOTH"]
CHANNELS = ["web", "app", "store", "phone"]
STATUSES = ["PLACED", "SHIPPED", "DELIVERED", "DELIVERED", "DELIVERED", "CANCELLED"]

client = boto3.client("redshift-data")


def run_sql(sql: str, quiet: bool = False):
    r = client.execute_statement(WorkgroupName=WORKGROUP, Database=DATABASE, Sql=sql)
    sid = r["Id"]
    while True:
        d = client.describe_statement(Id=sid)
        if d["Status"] in ("FINISHED", "FAILED", "ABORTED"):
            break
        time.sleep(1)
    if d["Status"] != "FINISHED":
        raise RuntimeError(f"SQL failed: {d.get('Error')}\n{sql[:300]}")
    if not quiet:
        print(f"ok ({d['Status']}): {sql.strip().splitlines()[0][:80]}")
    return sid


def fetch(sql: str):
    sid = run_sql(sql, quiet=True)
    res = client.get_statement_result(Id=sid)
    return [[list(c.values())[0] for c in row] for row in res["Records"]]


def run_file(path: pathlib.Path):
    text = path.read_text()
    for stmt in [s.strip() for s in text.split(";") if s.strip() and not s.strip().startswith("--")]:
        run_sql(stmt)


def seed(n_customers=2000, days=365, seed=42):
    rng = random.Random(seed)
    base = dt.date.today() - dt.timedelta(days=days)

    # customers
    rows = []
    for i in range(1, n_customers + 1):
        code = f"CUST{i:06d}"
        region = rng.choice(REGIONS)
        signup = base + dt.timedelta(days=rng.randint(0, days - 30))
        rows.append(
            f"('{code}','Customer {i}','cust{i}@example.com','{region}','{signup}',true)"
        )
    for chunk in range(0, len(rows), 500):
        run_sql(
            "INSERT INTO core.customers (customer_code, full_name, email, region, signup_date, is_active) VALUES "
            + ",".join(rows[chunk : chunk + 500]),
            quiet=True,
        )
    print(f"seeded {n_customers} customers")

    # orders + items
    order_values, item_values, order_id = [], [], 0
    for cust in range(1, n_customers + 1):
        for _ in range(rng.randint(5, 55)):
            order_id += 1
            ts = dt.datetime.combine(
                base + dt.timedelta(days=rng.randint(0, days - 1)),
                dt.time(rng.randint(0, 23), rng.randint(0, 59), rng.randint(0, 59)),
            )
            status = rng.choice(STATUSES)
            channel = rng.choice(CHANNELS)
            n_items = rng.randint(1, 4)
            total = 0
            for _ in range(n_items):
                qty = rng.randint(1, 5)
                price = round(rng.uniform(3.99, 249.99), 2)
                disc = rng.choice([0, 0, 0, 0.05, 0.1])
                item_values.append(
                    f"({order_id},'SKU{rng.randint(1,500):07d}',{qty},{price},{disc})"
                )
                total += round(qty * price * (1 - disc), 2)
            order_values.append(
                f"({cust},'{ts}','{status}',{round(total,2)},'{channel}')"
            )
    for chunk in range(0, len(order_values), 500):
        run_sql(
            "INSERT INTO core.orders (customer_id, order_ts, order_status, order_total, sales_channel) VALUES "
            + ",".join(order_values[chunk : chunk + 500]),
            quiet=True,
        )
    print(f"seeded {len(order_values)} orders")
    for chunk in range(0, len(item_values), 500):
        run_sql(
            "INSERT INTO core.order_items (order_id, sku, quantity, unit_price, discount_pct) VALUES "
            + ",".join(item_values[chunk : chunk + 500]),
            quiet=True,
        )
    print(f"seeded {len(item_values)} order items")


def verify():
    for t in ["core.customers", "core.orders", "core.order_items",
              "mart.daily_revenue", "mart.customer_ltv"]:
        try:
            n = fetch(f"SELECT COUNT(*) FROM {t}")[0][0]
        except RuntimeError:
            n = "(missing)"
        print(f"{t}: {n}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--verify", action="store_true")
    args = ap.parse_args()
    if args.verify:
        verify()
        return
    for f in sorted((ROOT / "sql" / "ddl").glob("*.sql")):
        run_file(f)
    seed()
    for f in sorted((ROOT / "sql" / "etl").glob("1[01]_*.sql")):
        run_file(f)
    verify()


if __name__ == "__main__":
    main()
