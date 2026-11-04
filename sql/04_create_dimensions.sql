
-- ===========================================
-- STEP 4.1: CREATE DIMENSION TABLES
-- ===========================================

BEGIN;

-- 1. CUSTOMER DIMENSION
CREATE TABLE IF NOT EXISTS mart.dim_customers (
    customer_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id TEXT NOT NULL UNIQUE,
    customer_unique_id TEXT,
    customer_zip_code_prefix TEXT,
    customer_city TEXT,
    customer_state TEXT
);

-- 2. PRODUCT DIMENSION
CREATE TABLE IF NOT EXISTS mart.dim_products (
    product_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id TEXT NOT NULL UNIQUE,
    product_category_name TEXT,
    product_weight_g NUMERIC(12,2),
    product_length_cm NUMERIC(12,2),
    product_height_cm NUMERIC(12,2),
    product_width_cm NUMERIC(12,2)
);

-- 3. SELLER DIMENSION
CREATE TABLE IF NOT EXISTS mart.dim_sellers (
    seller_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    seller_id TEXT NOT NULL UNIQUE,
    seller_zip_code_prefix TEXT,
    seller_city TEXT,
    seller_state TEXT
);

-- 4. DATE DIMENSION
CREATE TABLE IF NOT EXISTS mart.dim_date (
    date_key INTEGER PRIMARY KEY,
    calendar_date DATE NOT NULL UNIQUE,
    year INTEGER,
    quarter INTEGER,
    month INTEGER,
    day_of_month INTEGER,
    day_of_week INTEGER,
    is_weekend BOOLEAN
);

-- ===========================================
-- LOAD CUSTOMER DIMENSION
-- ===========================================

INSERT INTO mart.dim_customers (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
FROM staging.customers
ON CONFLICT (customer_id)
DO UPDATE SET
    customer_unique_id = EXCLUDED.customer_unique_id,
    customer_zip_code_prefix = EXCLUDED.customer_zip_code_prefix,
    customer_city = EXCLUDED.customer_city,
    customer_state = EXCLUDED.customer_state;

-- ===========================================
-- LOAD PRODUCT DIMENSION
-- ===========================================

INSERT INTO mart.dim_products (
    product_id,
    product_category_name,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
)
SELECT
    product_id,
    COALESCE(product_category_name, 'Unknown'),
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM staging.products
ON CONFLICT (product_id)
DO UPDATE SET
    product_category_name = EXCLUDED.product_category_name,
    product_weight_g = EXCLUDED.product_weight_g,
    product_length_cm = EXCLUDED.product_length_cm,
    product_height_cm = EXCLUDED.product_height_cm,
    product_width_cm = EXCLUDED.product_width_cm;

-- ===========================================
-- LOAD SELLER DIMENSION
-- ===========================================

INSERT INTO mart.dim_sellers (
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
)
SELECT
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
FROM staging.sellers
ON CONFLICT (seller_id)
DO UPDATE SET
    seller_zip_code_prefix = EXCLUDED.seller_zip_code_prefix,
    seller_city = EXCLUDED.seller_city,
    seller_state = EXCLUDED.seller_state;

-- ===========================================
-- LOAD DATE DIMENSION
-- ===========================================

INSERT INTO mart.dim_date (
    date_key,
    calendar_date,
    year,
    quarter,
    month,
    day_of_month,
    day_of_week,
    is_weekend
)
SELECT
    TO_CHAR(d.calendar_date, 'YYYYMMDD')::INTEGER,
    d.calendar_date,
    EXTRACT(YEAR FROM d.calendar_date)::INTEGER,
    EXTRACT(QUARTER FROM d.calendar_date)::INTEGER,
    EXTRACT(MONTH FROM d.calendar_date)::INTEGER,
    EXTRACT(DAY FROM d.calendar_date)::INTEGER,
    EXTRACT(ISODOW FROM d.calendar_date)::INTEGER,
    EXTRACT(ISODOW FROM d.calendar_date) IN (6, 7)
FROM (
    SELECT
        generate_series(
            (SELECT MIN(order_purchase_timestamp)::DATE
             FROM staging.orders),
            (SELECT MAX(order_purchase_timestamp)::DATE
             FROM staging.orders),
            INTERVAL '1 day'
        )::DATE AS calendar_date
) d
ON CONFLICT (date_key)
DO NOTHING;

COMMIT;

-- row number of Dimension Tables
SELECT 'dim_customers' AS table_name, COUNT(*) AS row_count
FROM mart.dim_customers

UNION ALL
SELECT 'dim_products', COUNT(*) FROM mart.dim_products

UNION ALL
SELECT 'dim_sellers', COUNT(*) FROM mart.dim_sellers

UNION ALL
SELECT 'dim_date', COUNT(*) FROM mart.dim_date

ORDER BY table_name;

--Test 2 — check category Unknown
SELECT
    product_category_name,
    COUNT(*) AS total_products
FROM mart.dim_products
WHERE product_category_name = 'Unknown'
GROUP BY product_category_name;

--  Test the unique of natural key
SELECT
    COUNT(*) AS total_products,
    COUNT(DISTINCT product_id) AS unique_products,
    COUNT(DISTINCT product_key) AS unique_keys
FROM mart.dim_products;