-- Unity Catalog layout for the order-analytics warehouse (medallion).
--   core   = bronze: append-only landing copy of the Redshift core tables
--   silver = enriched orders (orders x customers, cancelled orders removed)
--   mart   = gold: BI-facing marts (daily_revenue, customer_ltv)
-- Schema names core/mart are kept from Redshift so the recon harness and the
-- BI reports keep working with a catalog prefix only.
CREATE CATALOG IF NOT EXISTS migration_demo;

CREATE SCHEMA IF NOT EXISTS migration_demo.core
  COMMENT 'Bronze: append-only copy of the Redshift core schema';
CREATE SCHEMA IF NOT EXISTS migration_demo.silver
  COMMENT 'Silver: enriched, cancelled-free orders shared by every mart';
CREATE SCHEMA IF NOT EXISTS migration_demo.mart
  COMMENT 'Gold: BI marts';
