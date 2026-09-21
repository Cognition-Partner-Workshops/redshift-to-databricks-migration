# Factory doctor

The requested doctor command was attempted after allowlist merge `930e46d`.
The environment guard still blocked it before execution. No capabilities JSON
was produced.

Exact first error:

```text
Tool rejected: dbx-migration-factory guard: statement built at run time against legacy source ['TRINO_OPS_DSN'] in a program (legacy is read-only in every phase). Fix the command or, if the target is legitimate, add it to .migration/allowed_targets.json by a PR to the protected branch carrying a `D-<id>` row in 06_decisions.md (allowlist in force: HEAD:.migration/allowed_targets.json); never work around the guard.
```

Exact second error from the no-source-secret retry:

```text
Tool rejected: dbx-migration-factory guard: Python statement or connection is built at run time; the guard cannot resolve a non-read statement. Fix the command or, if the target is legitimate, add it to .migration/allowed_targets.json by a PR to the protected branch carrying a `D-<id>` row in 06_decisions.md (allowlist in force: HEAD:.migration/allowed_targets.json); never work around the guard.
```

Expected doctor findings could not be emitted because the guard prevented
doctor execution: the organization playbook library is not installed,
the session hook is not loaded, the configured Databricks identity is a
human PAT rather than OAuth M2M, and the allowlist-committed row cannot be
observed in a doctor report.
