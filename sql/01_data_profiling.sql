-- Missing values
SELECT
    COUNT(*) AS total_rows,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(order_id), '') IS NULL
    ) AS missing_order_id,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(customer_id), '') IS NULL
    ) AS missing_customer_id,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(order_purchase_timestamp), '') IS NULL
    ) AS missing_purchase_date,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(order_delivered_customer_date), '') IS NULL
    ) AS missing_delivery_date

FROM raw.orders;

-- Duplicate primary keys order_id
SELECT
    order_id,
    COUNT(*) AS occurrences
FROM raw.orders
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC
LIMIT 20;

-- Duplicate primary keys customer_id
SELECT
    customer_id,
    COUNT(*) AS occurrences
FROM raw.customers
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC
LIMIT 20;

-- Data consistency between table - custumer
SELECT
    COUNT(*) AS orphan_orders
FROM raw.orders o
LEFT JOIN raw.customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- order_items
SELECT
    COUNT(*) AS orphan_order_items
FROM raw.order_items oi
LEFT JOIN raw.orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- order status scater
SELECT
    order_status,
    COUNT(*) AS total_orders
FROM raw.orders
GROUP BY order_status
ORDER BY total_orders DESC;

-- Missing Delivery Date follow Order Status
SELECT
    order_status,
    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE NULLIF(
            TRIM(order_delivered_customer_date), ''
        ) IS NULL
    ) AS missing_delivery_date,

    COUNT(*) FILTER (
        WHERE NULLIF(
            TRIM(order_delivered_customer_date), ''
        ) IS NOT NULL
    ) AS has_delivery_date

FROM raw.orders
GROUP BY order_status
ORDER BY total_orders DESC;