-- ops.public (PostgreSQL, read through the Trino postgresql connector).
-- serial -> INT, char(n)/varchar(n) kept as CHAR(n)/VARCHAR(n), text -> STRING, timestamp -> TIMESTAMP.
CREATE TABLE IF NOT EXISTS trino_migration_demo.ops.customers (
    customer_id   INT          NOT NULL,
    customer_code CHAR(12)     NOT NULL,
    full_name     VARCHAR(120) NOT NULL,
    email         VARCHAR(160) NOT NULL,
    region        CHAR(4)      NOT NULL,
    signup_date   DATE         NOT NULL,
    is_active     BOOLEAN      NOT NULL,
    created_at    TIMESTAMP    NOT NULL,
    CONSTRAINT customers_pk PRIMARY KEY (customer_id)
);

CREATE TABLE IF NOT EXISTS trino_migration_demo.ops.customer_tags (
    customer_id INT    NOT NULL,
    tag         STRING NOT NULL,
    CONSTRAINT customer_tags_pk PRIMARY KEY (customer_id, tag),
    CONSTRAINT customer_tags_customer_fk FOREIGN KEY (customer_id) REFERENCES trino_migration_demo.ops.customers (customer_id)
);
