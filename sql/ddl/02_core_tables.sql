-- Core tables. Note the Redshift-isms: DISTKEY/SORTKEY, CHAR blank-padding,
-- IDENTITY columns, GETDATE() defaults.

CREATE TABLE IF NOT EXISTS core.customers (
    customer_id   INTEGER IDENTITY(1,1),
    customer_code CHAR(12)      NOT NULL,          -- CHAR: blank-padded in Redshift
    full_name     VARCHAR(120)  NOT NULL,
    email         VARCHAR(160),
    region        CHAR(4)       NOT NULL,          -- e.g. 'WEST', 'EAST'
    signup_date   DATE          NOT NULL,
    is_active     BOOLEAN       DEFAULT TRUE,
    created_at    TIMESTAMP     DEFAULT GETDATE()
)
DISTSTYLE KEY
DISTKEY (customer_id)
SORTKEY (signup_date);

CREATE TABLE IF NOT EXISTS core.orders (
    order_id      BIGINT IDENTITY(1,1),
    customer_id   INTEGER       NOT NULL,
    order_ts      TIMESTAMP     NOT NULL,
    order_status  CHAR(10)      NOT NULL,          -- 'PLACED', 'SHIPPED', ...
    order_total   DECIMAL(12,2) NOT NULL,
    sales_channel VARCHAR(20)   DEFAULT 'web',
    loaded_at     TIMESTAMP     DEFAULT GETDATE()
)
DISTSTYLE KEY
DISTKEY (customer_id)
COMPOUND SORTKEY (order_ts, customer_id);

CREATE TABLE IF NOT EXISTS core.order_items (
    order_item_id BIGINT IDENTITY(1,1),
    order_id      BIGINT        NOT NULL,
    sku           CHAR(16)      NOT NULL,
    quantity      SMALLINT      NOT NULL,
    unit_price    DECIMAL(10,2) NOT NULL,
    discount_pct  DECIMAL(5,4)  DEFAULT 0
)
DISTSTYLE KEY
DISTKEY (order_id)
SORTKEY (order_id);
