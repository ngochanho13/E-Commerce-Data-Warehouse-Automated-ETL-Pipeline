
-- ==============================================
-- ANALYTICS VIEWS VALIDATION
-- ==============================================

-- Test 1: Check view row counts

SELECT
    (SELECT COUNT(*)
     FROM mart.v_monthly_sales)
        AS monthly_rows,

    (SELECT COUNT(*)
     FROM mart.v_product_performance)
        AS category_rows,

    (SELECT COUNT(*)
     FROM mart.v_seller_performance)
        AS seller_rows;


-- Test 2: Reconcile category totals

SELECT
    (SELECT SUM(item_value_brl)
     FROM mart.v_product_performance)
        AS category_total,

    (SELECT SUM(item_price)
     FROM mart.fact_order_items
     WHERE order_status = 'delivered')
        AS fact_total;


-- Test 3: Reconcile seller totals

SELECT
    (SELECT SUM(item_value_brl)
     FROM mart.v_seller_performance)
        AS seller_total,

    (SELECT SUM(item_price)
     FROM mart.fact_order_items
     WHERE order_status = 'delivered')
        AS fact_total;


-- Test 4: Reconcile monthly item value

SELECT
    (SELECT SUM(item_value_brl)
     FROM mart.v_monthly_sales)
        AS monthly_total,

    (SELECT SUM(item_price)
     FROM mart.fact_order_items
     WHERE order_status = 'delivered')
        AS fact_total;
