# Run 2 factory-mode evidence

Run 2 adds the `.migration/` factory workspace, protected-branch allowlist,
factory-doctor contract, wave plans, cost estimates, and a reconciliation
harness merge gate over run 1's manual conversion. Legacy `trino/` remains
read-only.

Factory-doctor was attempted after allowlist merge `930e46d`, but the
environment guard blocked both the legacy-secret and no-secret invocations.
The exact messages and expected unobserved rows are in
`factory_doctor.md`. The org playbook library was not installed, the hook was
not loaded in this session, and the configured identity is a human PAT rather
than OAuth M2M; no doctor JSON was fabricated.

`dbx-recon selftest` passed through the source module with
`dbx-recon selftest PASS: 9 canonicalization rules exercised`. Estimates
completed for both units (10 source and 8 target statements each), recorded
in `marts_estimate.json` and `ops_tables_estimate.json`. The requested
reconciliation runs were attempted but did not produce harness result files:
the package install did not expose its console script, required migration
secrets could not be injected under the guard, and the direct retries report
the missing secret names in `recon_harness.md`. Wave result files therefore
use `recon_verdict: NOT_RUN`, never a fabricated `PASS`.

Report 22 exact medians and rankings match by promo. The Databricks query and
read-only Trino exact-median query are compared in `report_22_recon.md`.

Not done: organization playbook installation, child fan-out, a live Trino
source adapter, and cutover. These were outside the brief or unavailable:
fan-out and cutover were explicitly forbidden, the org library was not
installed, the harness has no Trino source adapter, and no cutover principal
or STOP E authorization exists.

Workflow preflight was attempted and halted before launch because the
declared gate hash was not recorded in the authored STOP C decision:
`manifest 'gates_sha' 'b45bdb080016b4bff2fd868d8afa724fdda4e4593c078424a3d76d28c3f7be55' is not approved by row 'D-4' ...`.
