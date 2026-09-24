-- Unity Catalog / Delta equivalent of sql/ddl/02_core_tables.sql.
--
-- Translation notes (Redshift -> Databricks):
--   IDENTITY(1,1)          -> plain BIGINT/INT. Keys are copied from Redshift during the
--                             backfill, so the target must accept explicit values. No
--                             identity generation on the target while Redshift is the
--                             system of record.
--   CHAR(n)                -> STRING. Lakehouse Federation surfaces Redshift CHAR as STRING
--                             and preserves the blank padding. Downstream SQL must not rely
--                             on Redshift's trailing-blank-insensitive CHAR compare
--                             (e.g. order_status <> 'CANCELLED  ') and should use RTRIM().
--   VARCHAR(n)             -> STRING.
--   SMALLINT               -> INT (federation type for Redshift SMALLINT).
--   DECIMAL(p,s)           -> DECIMAL(p,s), unchanged.
--   DEFAULT GETDATE()      -> dropped. loaded_at/created_at are copied from the source.
--   DISTSTYLE/DISTKEY      -> dropped (no equivalent needed on Delta).
--   SORTKEY                -> CLUSTER BY (liquid clustering) on the same columns.

CREATE TABLE IF NOT EXISTS migration_demo.core.customers (
    customer_id   INT           NOT NULL,
    customer_code STRING        NOT NULL COMMENT 'Redshift CHAR(12), blank-padded',
    full_name     STRING        NOT NULL,
    email         STRING,
    region        STRING        NOT NULL COMMENT 'Redshift CHAR(4), e.g. WEST, EAST',
    signup_date   DATE          NOT NULL,
    is_active     BOOLEAN,
    created_at    TIMESTAMP
)
USING DELTA
CLUSTER BY (signup_date)
COMMENT 'Mirror of Redshift core.customers';

CREATE TABLE IF NOT EXISTS migration_demo.core.orders (
    order_id      BIGINT        NOT NULL,
    customer_id   INT           NOT NULL,
    order_ts      TIMESTAMP     NOT NULL,
    order_status  STRING        NOT NULL COMMENT 'Redshift CHAR(10), blank-padded: PLACED, SHIPPED, CANCELLED, ...',
    order_total   DECIMAL(12,2) NOT NULL,
    sales_channel STRING,
    loaded_at     TIMESTAMP
)
USING DELTA
CLUSTER BY (order_ts, customer_id)
COMMENT 'Mirror of Redshift core.orders';

CREATE TABLE IF NOT EXISTS migration_demo.core.order_items (
    order_item_id BIGINT        NOT NULL,
    order_id      BIGINT        NOT NULL,
    sku           STRING        NOT NULL COMMENT 'Redshift CHAR(16), blank-padded',
    quantity      INT           NOT NULL,
    unit_price    DECIMAL(10,2) NOT NULL,
    discount_pct  DECIMAL(5,4)
)
USING DELTA
CLUSTER BY (order_id)
COMMENT 'Mirror of Redshift core.order_items';
