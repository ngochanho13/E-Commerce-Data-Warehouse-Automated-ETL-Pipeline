
-- ===============================================
-- STEP 3.3: COMPLETE STAGING LAYER
-- ===============================================

BEGIN;

-- 1. PRODUCTS
CREATE TABLE IF NOT EXISTS staging.products (
    product_id TEXT PRIMARY KEY,
    product_category_name TEXT,
    product_name_length INTEGER,
    product_description_length INTEGER,
    product_photos_qty INTEGER,
    product_weight_g NUMERIC(12,2),
    product_length_cm NUMERIC(12,2),
    product_height_cm NUMERIC(12,2),
    product_width_cm NUMERIC(12,2)
);

-- 2. SELLERS
CREATE TABLE IF NOT EXISTS staging.sellers (
    seller_id TEXT PRIMARY KEY,
    seller_zip_code_prefix TEXT,
    seller_city TEXT,
    seller_state TEXT
);

-- 3. ORDER ITEMS
CREATE TABLE IF NOT EXISTS staging.order_items (
    order_id TEXT NOT NULL,
    order_item_id INTEGER NOT NULL,
    product_id TEXT NOT NULL,
    seller_id TEXT NOT NULL,
    shipping_limit_date TIMESTAMP,
    price NUMERIC(12,2),
    freight_value NUMERIC(12,2),

    PRIMARY KEY (order_id, order_item_id),

    FOREIGN KEY (order_id)
        REFERENCES staging.orders(order_id),

    FOREIGN KEY (product_id)
        REFERENCES staging.products(product_id),

    FOREIGN KEY (seller_id)
        REFERENCES staging.sellers(seller_id)
);

-- 4. ORDER PAYMENTS
CREATE TABLE IF NOT EXISTS staging.order_payments (
    order_id TEXT NOT NULL,
    payment_sequential INTEGER NOT NULL,
    payment_type TEXT,
    payment_installments INTEGER,
    payment_value NUMERIC(12,2),

    PRIMARY KEY (order_id, payment_sequential),

    FOREIGN KEY (order_id)
        REFERENCES staging.orders(order_id)
);

-- 5. ORDER REVIEWS
CREATE TABLE IF NOT EXISTS staging.order_reviews (
    review_id TEXT,
    order_id TEXT,
    review_score INTEGER,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP,

    FOREIGN KEY (order_id)
        REFERENCES staging.orders(order_id)
);

-- ===============================================
-- FULL REFRESH
-- ===============================================

TRUNCATE TABLE
    staging.order_items,
    staging.order_payments,
    staging.order_reviews,
    staging.products,
    staging.sellers;

-- ===============================================
-- LOAD PRODUCTS
-- ===============================================

INSERT INTO staging.products
SELECT
    NULLIF(TRIM(product_id), ''),
    NULLIF(TRIM(product_category_name), ''),
    NULLIF(TRIM(product_name_lenght), '')::INTEGER,
    NULLIF(TRIM(product_description_lenght), '')::INTEGER,
    NULLIF(TRIM(product_photos_qty), '')::INTEGER,
    NULLIF(TRIM(product_weight_g), '')::NUMERIC(12,2),
    NULLIF(TRIM(product_length_cm), '')::NUMERIC(12,2),
    NULLIF(TRIM(product_height_cm), '')::NUMERIC(12,2),
    NULLIF(TRIM(product_width_cm), '')::NUMERIC(12,2)
FROM raw.products;

-- ===============================================
-- LOAD SELLERS
-- ===============================================

INSERT INTO staging.sellers
SELECT
    NULLIF(TRIM(seller_id), ''),
    NULLIF(TRIM(seller_zip_code_prefix), ''),
    NULLIF(TRIM(seller_city), ''),
    NULLIF(TRIM(seller_state), '')
FROM raw.sellers;

-- ===============================================
-- LOAD ORDER ITEMS
-- ===============================================

INSERT INTO staging.order_items
SELECT
    NULLIF(TRIM(order_id), ''),
    NULLIF(TRIM(order_item_id), '')::INTEGER,
    NULLIF(TRIM(product_id), ''),
    NULLIF(TRIM(seller_id), ''),
    NULLIF(TRIM(shipping_limit_date), '')::TIMESTAMP,
    NULLIF(TRIM(price), '')::NUMERIC(12,2),
    NULLIF(TRIM(freight_value), '')::NUMERIC(12,2)
FROM raw.order_items;

-- ===============================================
-- LOAD ORDER PAYMENTS
-- ===============================================

INSERT INTO staging.order_payments
SELECT
    NULLIF(TRIM(order_id), ''),
    NULLIF(TRIM(payment_sequential), '')::INTEGER,
    NULLIF(TRIM(payment_type), ''),
    NULLIF(TRIM(payment_installments), '')::INTEGER,
    NULLIF(TRIM(payment_value), '')::NUMERIC(12,2)
FROM raw.order_payments;

-- ===============================================
-- LOAD ORDER REVIEWS
-- ===============================================

INSERT INTO staging.order_reviews
SELECT
    NULLIF(TRIM(review_id), ''),
    NULLIF(TRIM(order_id), ''),
    NULLIF(TRIM(review_score), '')::INTEGER,
    NULLIF(TRIM(review_comment_title), ''),
    NULLIF(TRIM(review_comment_message), ''),
    NULLIF(TRIM(review_creation_date), '')::TIMESTAMP,
    NULLIF(TRIM(review_answer_timestamp), '')::TIMESTAMP
FROM raw.order_reviews;

COMMIT;
-- Check record
SELECT 'customers' AS table_name, COUNT(*) AS row_count
FROM staging.customers

UNION ALL
SELECT 'orders', COUNT(*) FROM staging.orders

UNION ALL
SELECT 'order_items', COUNT(*) FROM staging.order_items

UNION ALL
SELECT 'products', COUNT(*) FROM staging.products

UNION ALL
SELECT 'sellers', COUNT(*) FROM staging.sellers

UNION ALL
SELECT 'order_payments', COUNT(*) FROM staging.order_payments

UNION ALL
SELECT 'order_reviews', COUNT(*) FROM staging.order_reviews

ORDER BY table_name;

-- Missing values in Products
SELECT
    COUNT(*) AS total_products,

    COUNT(*) FILTER (
        WHERE product_category_name IS NULL
    ) AS missing_category,

    COUNT(*) FILTER (
        WHERE product_weight_g IS NULL
    ) AS missing_weight,

    COUNT(*) FILTER (
        WHERE product_length_cm IS NULL
    ) AS missing_length

FROM staging.products;

-- Check unsual value in Order Items
SELECT
    COUNT(*) AS total_items,

    COUNT(*) FILTER (
        WHERE price IS NULL
    ) AS missing_price,

    COUNT(*) FILTER (
        WHERE price < 0
    ) AS negative_price,

    COUNT(*) FILTER (
        WHERE freight_value < 0
    ) AS negative_freight

FROM staging.order_items;

-- Check Payment Values
SELECT
    COUNT(*) AS total_payments,

    COUNT(*) FILTER (
        WHERE payment_value IS NULL
    ) AS missing_payment,

    COUNT(*) FILTER (
        WHERE payment_value < 0
    ) AS negative_payment,

    COUNT(*) FILTER (
        WHERE payment_value = 0
    ) AS zero_payment

FROM staging.order_payments;

-- Check Review Scores
SELECT
    review_score,
    COUNT(*) AS total_reviews
FROM staging.order_reviews
GROUP BY review_score
ORDER BY review_score;