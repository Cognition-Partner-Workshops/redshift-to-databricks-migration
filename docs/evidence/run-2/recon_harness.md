# Reconciliation harness

The requested editable install failed before installation:

```text
ERROR: Project file:///home/ubuntu/repos/dbx-migration-plugin/skills/data-reconciliation/harness has a 'pyproject.toml' and its build backend is missing the 'build_editable' hook. Since it does not have a 'setup.py' nor a 'setup.cfg', it cannot be installed in editable mode. Consider using a build backend that supports PEP 660.
```

The non-editable fallback installed `UNKNOWN-0.0.0` and did not install the
`dbx-recon` console script:

```text
WARNING: unknown 0.0.0 does not provide the extra 'databricks'
WARNING: unknown 0.0.0 does not provide the extra 'lakebase'
Successfully installed UNKNOWN-0.0.0
bash: line 1: dbx-recon: command not found
```

The source module self-test was run without changing the harness:

```text
dbx-recon selftest PASS: 9 canonicalization rules exercised
```

Both estimates ran through the source module:

- `marts_estimate.json`: snapshot/full, 10 source and 8 target statements.
- `ops_tables_estimate.json`: live/full, 10 source and 8 target statements.

The requested runs were attempted through the source module. Because the
editable install did not provide the console entry point, the equivalent
module invocation was used without changing the harness. With no migration
secret environment injected, the marts attempt stopped at:

```text
RuntimeError: secret 'DATABRICKS_MIGRATION_SQL' not found in environment; pass secrets by name only
```

After installing the missing optional `psycopg[binary]` dependency (the
non-editable fallback did not install extras), the ops attempt stopped at:

```text
RuntimeError: secret 'TRINO_OPS_DSN' not found in environment; pass secrets by name only
```

An attempt to build the required migration-secret environment was blocked by
the factory guard before the harness could start:

Exact error:

```text
Tool rejected: dbx-migration-factory guard: identity swap: `DATABRICKS_MIGRATION_SQL=` changed for the session; the session runs as the doctor-verified migration principal only. Fix the command or, if the target is legitimate, add it to .migration/allowed_targets.json by a PR to the protected branch carrying a `D-<id>` row in 06_decisions.md (allowlist in force: HEAD:.migration/allowed_targets.json); never work around the guard.
```
