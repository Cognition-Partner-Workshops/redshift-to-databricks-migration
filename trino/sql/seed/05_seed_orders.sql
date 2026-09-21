INSERT INTO lake.core.orders
SELECT
    CAST(n AS BIGINT) AS order_id,
    CAST(((n - 1) % 200) + 1 AS INTEGER) AS customer_id,
    CAST(date_add('minute', -((n * 37) % 172800), current_timestamp) AS TIMESTAMP(3)) AS order_ts,
    element_at(ARRAY['PLACED', 'SHIPPED', 'DELIVERED', 'CANCELLED'], (n % 4) + 1) AS order_status,
    CAST(25.00 + ((n * 13) % 97500) / 100.0 AS DECIMAL(12, 2)) AS order_total,
    element_at(ARRAY['web', 'app', 'store'], (n % 3) + 1) AS sales_channel,
    map(
        ARRAY['promo', 'device'],
        ARRAY[
            element_at(ARRAY['NONE', 'WELCOME10', 'SPRING15', 'LOYALTY5'], (n % 4) + 1),
            element_at(ARRAY['desktop', 'mobile', 'tablet'], (n % 3) + 1)
        ]
    ) AS attrs,
    CAST(date_add('minute', -((n * 37) % 172800), current_timestamp) AS DATE) AS order_date
FROM UNNEST(sequence(1, 5000)) AS t(n);

INSERT INTO lake.core.order_items
SELECT
    CAST(i AS BIGINT) AS order_item_id,
    CAST(((i - 1) % 5000) + 1 AS BIGINT) AS order_id,
    format('SKU-%05d', ((i * 17) % 1000) + 1) AS sku,
    CAST(((i * 7) % 4) + 1 AS SMALLINT) AS quantity,
    CAST(5.00 + ((i * 19) % 25000) / 100.0 AS DECIMAL(10, 2)) AS unit_price,
    CAST(((i * 3) % 25) / 10000.0 AS DECIMAL(5, 4)) AS discount_pct
FROM UNNEST(sequence(1, 6000)) AS t(i);

INSERT INTO lake.core.order_items
SELECT
    CAST(i AS BIGINT) AS order_item_id,
    CAST(((i - 1) % 5000) + 1 AS BIGINT) AS order_id,
    format('SKU-%05d', ((i * 17) % 1000) + 1) AS sku,
    CAST(((i * 7) % 4) + 1 AS SMALLINT) AS quantity,
    CAST(5.00 + ((i * 19) % 25000) / 100.0 AS DECIMAL(10, 2)) AS unit_price,
    CAST(((i * 3) % 25) / 10000.0 AS DECIMAL(5, 4)) AS discount_pct
FROM UNNEST(sequence(6001, 12000)) AS t(i);
