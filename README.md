# Redshift → Databricks Migration Demo Estate

A synthetic but realistic "legacy Redshift" SQL estate used to demonstrate an
autonomous Redshift takeout: assessment, backfill via Lakehouse Federation,
SQL conversion with data-level reconciliation, and event-driven remediation
during the parallel-run period.

## Layout

- `sql/ddl/` — Redshift DDL (DISTKEY/SORTKEY, CHAR blank-padding, IDENTITY)
- `sql/etl/` — nightly mart builds (GETDATE, DECODE, TRUNC, DATEDIFF, a
  stored procedure, and a decimal `AVG` whose truncation semantics differ
  between Redshift and Databricks)
- `sql/reports/` — BI report queries consumed downstream
- `scripts/seed_redshift.py` — create + load the estate via the Redshift Data API
- `scripts/drift_loader.py` — land a new "day" of orders to stage freshness drift

## Environment

- Redshift Serverless: workgroup `demo-wg`, database `demo`, region `us-east-1`
- Admin user `demoadmin` (password in org secret `REDSHIFT_DEMO_ADMIN_PASSWORD`)
- AWS access via `AWS_DEMO_ACCESS_KEY_ID` / `AWS_DEMO_SECRET_ACCESS_KEY`

```bash
pip install boto3
export AWS_DEFAULT_REGION=us-east-1
python scripts/seed_redshift.py          # one-time seed
python scripts/seed_redshift.py --verify # row counts
python scripts/drift_loader.py           # stage drift before the recon beat
```
