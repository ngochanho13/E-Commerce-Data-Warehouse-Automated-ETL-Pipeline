-- Verify the current database
SELECT current_database();
-- Create schemas for the ETL pipeline
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS mart;
-- Check schema
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name IN ('raw', 'staging', 'mart')
ORDER BY schema_name;
--Check data
SELECT
    'customers' AS table_name,
    COUNT(*) AS row_count
FROM raw.customers

UNION ALL

SELECT 'orders', COUNT(*)
FROM raw.orders

UNION ALL

SELECT 'order_items', COUNT(*)
FROM raw.order_items

UNION ALL

SELECT 'products', COUNT(*)
FROM raw.products

UNION ALL

SELECT 'sellers', COUNT(*)
FROM raw.sellers

UNION ALL

SELECT 'order_payments', COUNT(*)
FROM raw.order_payments

UNION ALL

SELECT 'order_reviews', COUNT(*)
FROM raw.order_reviews

ORDER BY table_name;