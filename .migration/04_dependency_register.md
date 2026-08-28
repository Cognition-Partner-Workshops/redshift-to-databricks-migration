# 04 — Dependency Register

Taxonomy: D1 schema/DDL · D2 data availability · D3 upstream ingestion · D4 downstream consumers ·
D5 dialect/function semantics · D6 orchestration/schedule · D7 security/PII · D8 performance ·
D9 tooling · D10 access/environment prerequisite.

| ID | Type | Description | Status | Owner | Opened |
|---|---|---|---|---|---|
| DEP-001 | D4 | Query history (`sys_query_history`) accessible but sparse (8 rows at probe) — weak evidence for untracked-consumer detection; D4 sweeps rely on repo census instead | OPEN (accepted risk, demo estate) | user | 2026-08-28 |
| DEP-002 | D10 | Federation connection `redshift_demo` had a stale credential (all `redshift_src` queries failed BAD_REQUEST); credential refreshed 2026-08-28 and verified. Watch for recurrence if the demoadmin password rotates | RESOLVED | Devin | 2026-08-28 |
