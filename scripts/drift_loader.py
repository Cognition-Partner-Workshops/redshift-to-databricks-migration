#!/usr/bin/env python3
"""Load a fresh 'day' of orders into live Redshift so the migrated Databricks
copy goes stale. Run ~10 minutes before demoing the reconciliation beat.

Usage: python scripts/drift_loader.py [--orders 400]
"""
import argparse
import datetime as dt
import random

from seed_redshift import run_sql, fetch

CHANNELS = ["web", "app", "store", "phone"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--orders", type=int, default=400)
    args = ap.parse_args()

    rng = random.Random()
    n_customers = fetch("SELECT MAX(customer_id) FROM core.customers")[0][0]
    now = dt.datetime.now()
    values = []
    for _ in range(args.orders):
        cust = rng.randint(1, int(n_customers))
        ts = now - dt.timedelta(minutes=rng.randint(0, 1440))
        total = round(rng.uniform(9.99, 499.99), 2)
        values.append(
            f"({cust},'{ts:%Y-%m-%d %H:%M:%S}','PLACED',{total},'{rng.choice(CHANNELS)}')"
        )
    run_sql(
        "INSERT INTO core.orders (customer_id, order_ts, order_status, order_total, sales_channel) VALUES "
        + ",".join(values)
    )
    print(f"loaded {args.orders} new orders — the migrated copy is now stale")
    print("row count now:", fetch("SELECT COUNT(*) FROM core.orders")[0][0])


if __name__ == "__main__":
    main()
