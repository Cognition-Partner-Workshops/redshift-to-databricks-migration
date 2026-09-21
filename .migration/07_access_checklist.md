# Access checklist

## Assessment

- Databricks access uses PAT credentials through the secret names
  `DATABRICKS_DEMO_HOST` and `DATABRICKS_DEMO_TOKEN`.
- The identity is human rather than the expected OAuth M2M identity; this is a
  factory-doctor finding.

## Migration

- The harness uses scoped source and target access through secret names only.
- Target writes are limited to the migration catalog
  `trino_migration_demo` and its declared `ops` and `mart` schemas.

## Cutover

- None. There is no customer-held cutover principal, and STOP E is not
  authorized for this demo.
