# Run 2 conventions

- Base branch: `trino-migration-run-2`, created from
  `origin/trino-migration-run-1` and pushed before the work branch.
- Work branch: `devin/<unix-timestamp>-trino-run2-factory`.
- The user opens the PR; this session does not open or update one.
- Run 2 is factory mode using `.migration/`, factory-doctor, and `dbx-recon`.
- Run 1 was manual conversion and reconciliation.
- Legacy `trino/` files are read-only. No org playbooks, child fan-out, or
  cutover is authorized.
- Stops route to this session only.
- `stop_mode: hard`.
