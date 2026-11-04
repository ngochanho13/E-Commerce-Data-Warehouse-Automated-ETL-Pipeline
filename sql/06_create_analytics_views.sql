
-- ====================================================
-- E-COMMERCE DATA WAREHOUSE
-- STEP 9: CREATE ANALYTICS VIEWS
-- ====================================================

BEGIN;

-- ====================================================
-- 1. MONTHLY SALES ANALYTICS VIEW
-- ====================================================

CREATE OR REPLACE VIEW mart.v_monthly_sales AS

SELECT
    d.year,
    d.month,
    MAKE_DATE(d.year, d.month, 1) AS month_start,

    COUNT(DISTINCT f.order_id) AS total_orders,
    COUNT(*) AS total_items,

    ROUND(SUM(f.item_price), 2)
        AS item_value_brl,

    ROUND(SUM(f.freight_value), 2)
        AS freight_value_brl,

    ROUND(SUM(f.item_total_amount), 2)
        AS total_value_brl

FROM mart.fact_order_items f

JOIN mart.dim_date d
    ON f.order_date_key = d.date_key

WHERE f.order_status = 'delivered'

GROUP BY
    d.year,
    d.month;


-- ====================================================
-- 2. PRODUCT CATEGORY PERFORMANCE VIEW
-- ====================================================

CREATE OR REPLACE VIEW mart.v_product_performance AS

SELECT
    COALESCE(
        p.product_category_name,
        'Unknown'
    ) AS product_category,

    COUNT(*) AS total_items,

    COUNT(DISTINCT f.order_id)
        AS total_orders,

    ROUND(SUM(f.item_price), 2)
        AS item_value_brl,

    ROUND(SUM(f.freight_value), 2)
        AS freight_value_brl

FROM mart.fact_order_items f

JOIN mart.dim_products p
    ON f.product_key = p.product_key

WHERE f.order_status = 'delivered'

GROUP BY
    COALESCE(
        p.product_category_name,
        'Unknown'
    );


-- ====================================================
-- 3. SELLER PERFORMANCE VIEW
-- ====================================================

CREATE OR REPLACE VIEW mart.v_seller_performance AS

SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state,

    COUNT(*) AS total_items,

    COUNT(DISTINCT f.order_id)
        AS total_orders,

    ROUND(SUM(f.item_price), 2)
        AS item_value_brl,

    ROUND(SUM(f.freight_value), 2)
        AS freight_value_brl

FROM mart.fact_order_items f

JOIN mart.dim_sellers s
    ON f.seller_key = s.seller_key

WHERE f.order_status = 'delivered'

GROUP BY
    s.seller_id,
    s.seller_city,
    s.seller_state;

COMMIT;