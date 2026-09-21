CREATE TABLE public.customers (
    customer_id   serial PRIMARY KEY,
    customer_code char(12) NOT NULL,
    full_name     varchar(120) NOT NULL,
    email         varchar(160) NOT NULL,
    region        char(4) NOT NULL CHECK (region IN ('WEST', 'EAST', 'NORT', 'SOUT')),
    signup_date   date NOT NULL,
    is_active     boolean NOT NULL DEFAULT true,
    created_at    timestamp NOT NULL
);

CREATE TABLE public.customer_tags (
    customer_id integer NOT NULL REFERENCES public.customers(customer_id),
    tag text NOT NULL,
    PRIMARY KEY (customer_id, tag)
);

INSERT INTO public.customers (
    customer_id, customer_code, full_name, email, region, signup_date, is_active, created_at
)
SELECT
    n,
    rpad('CUST' || lpad(n::text, 8, '0'), 12, ' '),
    'Customer ' || lpad(n::text, 3, '0'),
    'customer' || lpad(n::text, 3, '0') || '@example.com',
    (ARRAY['WEST', 'EAST', 'NORT', 'SOUT'])[((n - 1) % 4) + 1],
    DATE '2020-01-01' + ((n * 11) % 1200),
    n % 10 <> 0,
    TIMESTAMP '2020-01-01 08:00:00' + (n * INTERVAL '1 hour')
FROM generate_series(1, 200) AS s(n);

INSERT INTO public.customer_tags (customer_id, tag)
SELECT
    n,
    CASE tag_number
        WHEN 1 THEN (ARRAY['loyalty', 'mobile', 'newsletter', 'priority'])[((n - 1) % 4) + 1]
        WHEN 2 THEN (ARRAY['wholesale', 'vip', 'seasonal', 'staff'])[((n + 1) % 4) + 1]
        ELSE (ARRAY['email', 'sms', 'partner', 'referral'])[((n + 2) % 4) + 1]
    END
FROM generate_series(1, 200) AS s(n)
CROSS JOIN generate_series(1, 3) AS t(tag_number)
WHERE tag_number <= (n % 3) + 1;
