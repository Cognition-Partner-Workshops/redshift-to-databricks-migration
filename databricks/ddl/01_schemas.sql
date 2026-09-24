-- Unity Catalog equivalent of sql/ddl/01_schemas.sql.
-- Redshift schemas core / mart become schemas inside the migration_demo catalog.
-- The catalog itself already exists in the workspace (created during federation setup).

CREATE SCHEMA IF NOT EXISTS migration_demo.core
  COMMENT 'Landing zone for Redshift core.* (customers, orders, order_items)';

CREATE SCHEMA IF NOT EXISTS migration_demo.mart
  COMMENT 'Aggregated marts rebuilt nightly from core (daily_revenue, customer_ltv)';
