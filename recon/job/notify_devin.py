# Databricks notebook source
# Runs only when the recon task fails: POSTs the failure to the Devin
# remediation webhook so an autonomous fix session is spawned.
import requests

WEBHOOK_URL = (
    "https://partner-workshops.devinenterprise.com/api/webhooks/automations/"
    "org-012fdeb7967c4e399b9d71cf5c857b63/auto-c7f7cb29571a4d379f46496797f6dc8a"
)

secret = dbutils.secrets.get("redshift_migration", "devin_webhook_secret")  # noqa: F821
dbutils.widgets.text("job_id", "")  # noqa: F821
dbutils.widgets.text("run_id", "")  # noqa: F821

payload = {
    "source": "databricks-recon-job",
    "event": "reconciliation_failed",
    "job_id": dbutils.widgets.get("job_id"),  # noqa: F821
    "run_id": dbutils.widgets.get("run_id"),  # noqa: F821
    "detail": "Scheduled Redshift->Databricks reconciliation job failed. "
              "See recon task output for the raise_error message.",
}

resp = requests.post(
    WEBHOOK_URL,
    headers={"Content-Type": "application/json", "X-Webhook-Secret": secret},
    json=payload,
    timeout=30,
)
print("Devin webhook response:", resp.status_code, resp.text[:500])
resp.raise_for_status()
