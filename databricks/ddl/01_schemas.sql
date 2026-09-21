CREATE CATALOG IF NOT EXISTS trino_migration_demo;
CREATE SCHEMA IF NOT EXISTS trino_migration_demo.trino_src;
CREATE SCHEMA IF NOT EXISTS trino_migration_demo.core;
CREATE SCHEMA IF NOT EXISTS trino_migration_demo.ops;
CREATE SCHEMA IF NOT EXISTS trino_migration_demo.mart;
CREATE VOLUME IF NOT EXISTS trino_migration_demo.trino_src.landing;
