-- Databricks setup: Lakehouse Federation to the live Redshift warehouse and
-- backfill of the core tables into Unity Catalog as Delta.
--
-- Prereq (Databricks REST/CLI, not SQL): secret scope `redshift_migration`
-- with keys `redshift_user` / `redshift_password` holding the Redshift
-- demoadmin credentials.
--
-- Run on the existing serverless SQL warehouse (id 565cd2fd713738c4).

CREATE CONNECTION IF NOT EXISTS redshift_demo TYPE redshift
OPTIONS (
  host 'demo-wg.599083837640.us-east-1.redshift-serverless.amazonaws.com',
  port '5439',
  user secret('redshift_migration', 'redshift_user'),
  password secret('redshift_migration', 'redshift_password')
);

CREATE FOREIGN CATALOG IF NOT EXISTS redshift_src
USING CONNECTION redshift_demo
OPTIONS (database 'demo');

-- Workspace uses Default Storage; plain CREATE CATALOG works on the warehouse.
CREATE CATALOG IF NOT EXISTS migration_demo;
CREATE SCHEMA IF NOT EXISTS migration_demo.core;
CREATE SCHEMA IF NOT EXISTS migration_demo.mart;

-- Backfill via federation (CTAS from the foreign catalog).
CREATE OR REPLACE TABLE migration_demo.core.customers   AS SELECT * FROM redshift_src.core.customers;
CREATE OR REPLACE TABLE migration_demo.core.orders      AS SELECT * FROM redshift_src.core.orders;
CREATE OR REPLACE TABLE migration_demo.core.order_items AS SELECT * FROM redshift_src.core.order_items;
