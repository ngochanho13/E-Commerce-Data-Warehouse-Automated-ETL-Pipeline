BEGIN;

-- 1. Create staging customers table
CREATE TABLE IF NOT EXISTS staging.customers (
    customer_id TEXT PRIMARY KEY,
    customer_unique_id TEXT,
    customer_zip_code_prefix TEXT,
    customer_city TEXT,
    customer_state TEXT
);

-- 2. Create staging orders table
CREATE TABLE IF NOT EXISTS staging.orders (
    order_id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL,
    order_status TEXT,
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES staging.customers(customer_id)
);

-- 3. Clear existing staging data for full refresh
TRUNCATE TABLE staging.orders, staging.customers CASCADE;

-- 4. Load cleaned customers
INSERT INTO staging.customers (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)
SELECT
    NULLIF(TRIM(customer_id), ''),
    NULLIF(TRIM(customer_unique_id), ''),
    NULLIF(TRIM(customer_zip_code_prefix), ''),
    NULLIF(TRIM(customer_city), ''),
    NULLIF(TRIM(customer_state), '')
FROM raw.customers;

-- 5. Load cleaned orders
INSERT INTO staging.orders (
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
)
SELECT
    NULLIF(TRIM(order_id), ''),
    NULLIF(TRIM(customer_id), ''),
    NULLIF(TRIM(order_status), ''),

    NULLIF(TRIM(order_purchase_timestamp), '')::TIMESTAMP,
    NULLIF(TRIM(order_approved_at), '')::TIMESTAMP,
    NULLIF(TRIM(order_delivered_carrier_date), '')::TIMESTAMP,
    NULLIF(TRIM(order_delivered_customer_date), '')::TIMESTAMP,
    NULLIF(TRIM(order_estimated_delivery_date), '')::TIMESTAMP

FROM raw.orders;

COMMIT;

-- Check row number
SELECT
    'customers' AS table_name,
    COUNT(*) AS total_rows
FROM staging.customers

UNION ALL

SELECT
    'orders',
    COUNT(*)
FROM staging.orders;

-- Check data type
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'staging'
  AND table_name = 'orders'
ORDER BY ordinal_position;

-- Check missing value after transaction
SELECT
    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NULL
    ) AS missing_delivery_date,

    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
        AND order_delivered_customer_date IS NULL
    ) AS delivered_missing_date,

    COUNT(*) FILTER (
        WHERE order_status = 'canceled'
        AND order_delivered_customer_date IS NOT NULL
    ) AS canceled_with_delivery_date

FROM staging.orders;

-- Show all order need to check
SELECT
    order_id,
    order_status,
    order_purchase_timestamp,
    order_delivered_customer_date
FROM staging.orders
WHERE
    (
        order_status = 'delivered'
        AND order_delivered_customer_date IS NULL
    )
    OR
    (
        order_status = 'canceled'
        AND order_delivered_customer_date IS NOT NULL
    )
ORDER BY order_status;