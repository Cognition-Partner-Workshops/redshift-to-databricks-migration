-- Silver: one enriched, cancelled-free order row shared by every gold mart.
-- Replaces the core.orders x core.customers join and the
-- order_status <> 'CANCELLED  ' filter that sql/etl/10_* and sql/etl/11_* each
-- repeated. Loaded incrementally by databricks/silver/05_load_enriched_orders.sql.

CREATE TABLE IF NOT EXISTS migration_demo.silver.enriched_orders (
    order_id      BIGINT        NOT NULL,
    customer_id   BIGINT        NOT NULL,
    customer_code STRING        NOT NULL,
    region        STRING        NOT NULL,
    order_ts      TIMESTAMP     NOT NULL,
    order_date    DATE          NOT NULL COMMENT 'to_date(order_ts), the Redshift TRUNC(order_ts)',
    order_status  STRING        NOT NULL COMMENT 'trimmed, never CANCELLED',
    sales_channel STRING,
    channel_group STRING        NOT NULL COMMENT 'ONLINE for web/app, otherwise RETAIL',
    order_total   DECIMAL(12,2) NOT NULL,
    enriched_at   TIMESTAMP     NOT NULL,
    CONSTRAINT enriched_orders_pk PRIMARY KEY (order_id)
)
USING DELTA
CLUSTER BY (order_date, customer_id)
COMMENT 'Valid (non-cancelled) orders joined to their customer. Source for mart.daily_revenue and mart.customer_ltv.';
