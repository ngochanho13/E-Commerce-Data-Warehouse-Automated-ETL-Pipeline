BEGIN;

-- 1. Create Fact Table
CREATE TABLE IF NOT EXISTS mart.fact_order_items (

    order_id TEXT NOT NULL,
    order_item_id INTEGER NOT NULL,

    -- Surrogate keys
    customer_key BIGINT NOT NULL,
    product_key BIGINT NOT NULL,
    seller_key BIGINT NOT NULL,
    order_date_key INTEGER NOT NULL,

    -- Order attributes
    order_status TEXT,
    order_purchase_timestamp TIMESTAMP,
    shipping_limit_date TIMESTAMP,

    -- Measures
    item_price NUMERIC(12,2),
    freight_value NUMERIC(12,2),
    item_total_amount NUMERIC(13,2),

    -- Composite primary key
    CONSTRAINT pk_fact_order_items
        PRIMARY KEY (order_id, order_item_id),

    -- Foreign keys
    CONSTRAINT fk_fact_customer
        FOREIGN KEY (customer_key)
        REFERENCES mart.dim_customers(customer_key),

    CONSTRAINT fk_fact_product
        FOREIGN KEY (product_key)
        REFERENCES mart.dim_products(product_key),

    CONSTRAINT fk_fact_seller
        FOREIGN KEY (seller_key)
        REFERENCES mart.dim_sellers(seller_key),

    CONSTRAINT fk_fact_date
        FOREIGN KEY (order_date_key)
        REFERENCES mart.dim_date(date_key)
);

-- 2. Full refresh
TRUNCATE TABLE mart.fact_order_items;

-- 3. Load Fact Table
INSERT INTO mart.fact_order_items (

    order_id,
    order_item_id,

    customer_key,
    product_key,
    seller_key,
    order_date_key,

    order_status,
    order_purchase_timestamp,
    shipping_limit_date,

    item_price,
    freight_value,
    item_total_amount
)

SELECT
    oi.order_id,
    oi.order_item_id,

    dc.customer_key,
    dp.product_key,
    ds.seller_key,
    dd.date_key,

    o.order_status,
    o.order_purchase_timestamp,
    oi.shipping_limit_date,

    oi.price,
    oi.freight_value,
    oi.price + oi.freight_value

FROM staging.order_items oi

JOIN staging.orders o
    ON oi.order_id = o.order_id

JOIN mart.dim_customers dc
    ON o.customer_id = dc.customer_id

JOIN mart.dim_products dp
    ON oi.product_id = dp.product_id

JOIN mart.dim_sellers ds
    ON oi.seller_id = ds.seller_id

JOIN mart.dim_date dd
    ON o.order_purchase_timestamp::DATE = dd.calendar_date;

-- 4. Validate completeness before committing
DO $$
DECLARE
    source_rows BIGINT;
    fact_rows BIGINT;
BEGIN
    SELECT COUNT(*) INTO source_rows
    FROM staging.order_items;

    SELECT COUNT(*) INTO fact_rows
    FROM mart.fact_order_items;

    IF fact_rows <> source_rows THEN
        RAISE EXCEPTION
            'Fact row count mismatch: source %, fact %',
            source_rows, fact_rows;
    END IF;
END $$;

COMMIT;

-- Check number of row
SELECT
    COUNT(*) AS total_fact_rows
FROM mart.fact_order_items;

-- Check the distinct
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (order_id, order_item_id)) AS unique_items
FROM mart.fact_order_items;

-- Check the sell value
SELECT
    COUNT(*) AS total_items,
    SUM(item_price) AS total_item_value,
    SUM(freight_value) AS total_freight,
    SUM(item_total_amount) AS total_amount
FROM mart.fact_order_items;

-- Recheck after JOIN
SELECT
    (SELECT SUM(price)
     FROM staging.order_items) AS staging_item_value,

    (SELECT SUM(item_price)
     FROM mart.fact_order_items) AS fact_item_value;

-- Check the order status in Fact
SELECT
    order_status,
    COUNT(*) AS total_items,
    SUM(item_price) AS total_item_value
FROM mart.fact_order_items
GROUP BY order_status
ORDER BY total_items DESC;

-- Check missing measure
SELECT
    COUNT(*) FILTER (
        WHERE item_price IS NULL
    ) AS missing_price,

    COUNT(*) FILTER (
        WHERE freight_value IS NULL
    ) AS missing_freight,

    COUNT(*) FILTER (
        WHERE item_total_amount IS NULL
    ) AS missing_total
FROM mart.fact_order_items;