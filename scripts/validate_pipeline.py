
import os
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL


# ============================================
# 1. DATABASE CONNECTION
# ============================================

BASE_DIR = Path(__file__).resolve().parents[1]
load_dotenv(BASE_DIR / ".env")

db_url = URL.create(
    drivername="postgresql+psycopg2",
    username=os.getenv("DB_USER", "postgres"),
    password=os.getenv("DB_PASSWORD"),
    host=os.getenv("DB_HOST", "localhost"),
    port=int(os.getenv("DB_PORT", "5432")),
    database=os.getenv("DB_NAME", "ecommerce_dw"),
)

engine = create_engine(db_url)

results = []


def run_check(name, condition, detail=""):
    passed = bool(condition)
    results.append(passed)

    status = "PASS" if passed else "FAIL"
    print(f"[{status}] {name} {detail}")


def get_count(conn, table):
    return conn.execute(
        text(f"SELECT COUNT(*) FROM {table}")
    ).scalar_one()


# ============================================
# 2. DATA QUALITY CHECKS
# ============================================

def validate_pipeline():

    with engine.connect() as conn:

        print("\n=== DATABASE VALIDATION ===")

        database = conn.execute(
            text("SELECT current_database()")
        ).scalar_one()

        run_check(
            "Correct database",
            database == "ecommerce_dw",
            f"({database})"
        )

        if database != "ecommerce_dw":
            raise RuntimeError("Wrong database connection")

        # ------------------------------------
        # CHECK 1: RAW vs STAGING
        # ------------------------------------

        print("\n=== RAW vs STAGING ===")

        tables = [
            "customers",
            "orders",
            "order_items",
            "products",
            "sellers",
            "order_payments",
            "order_reviews"
        ]

        for table in tables:

            raw_count = get_count(conn, f"raw.{table}")
            staging_count = get_count(
                conn, f"staging.{table}"
            )

            run_check(
                f"{table} row count",
                raw_count == staging_count
                and raw_count > 0,
                f"({raw_count:,} vs {staging_count:,})"
            )

        # ------------------------------------
        # CHECK 2: DIMENSION COMPLETENESS
        # ------------------------------------

        print("\n=== DIMENSIONS ===")

        dimensions = {
            "customers": "dim_customers",
            "products": "dim_products",
            "sellers": "dim_sellers"
        }

        for source, target in dimensions.items():

            source_count = get_count(
                conn, f"staging.{source}"
            )

            dim_count = get_count(
                conn, f"mart.{target}"
            )

            run_check(
                f"{target} completeness",
                source_count == dim_count,
                f"({source_count:,} vs {dim_count:,})"
            )

        # ------------------------------------
        # CHECK 3: FACT COMPLETENESS
        # ------------------------------------

        print("\n=== FACT TABLE ===")

        source_count = get_count(
            conn, "staging.order_items"
        )

        fact_count = get_count(
            conn, "mart.fact_order_items"
        )

        run_check(
            "Fact row count",
            source_count == fact_count
            and source_count > 0,
            f"({source_count:,} vs {fact_count:,})"
        )

        # ------------------------------------
        # CHECK 4: DUPLICATE FACT KEYS
        # ------------------------------------

        duplicates = conn.execute(text("""
            SELECT
                COUNT(*) -
                COUNT(DISTINCT (order_id, order_item_id))
            FROM mart.fact_order_items
        """)).scalar_one()

        run_check(
            "No duplicate fact keys",
            duplicates == 0,
            f"({duplicates} duplicates)"
        )

        # ------------------------------------
        # CHECK 5: FINANCIAL RECONCILIATION
        # ------------------------------------

        source_amounts = conn.execute(text("""
            SELECT
                COALESCE(SUM(price), 0),
                COALESCE(SUM(freight_value), 0)
            FROM staging.order_items
        """)).one()

        fact_amounts = conn.execute(text("""
            SELECT
                COALESCE(SUM(item_price), 0),
                COALESCE(SUM(freight_value), 0),
                COALESCE(SUM(item_total_amount), 0)
            FROM mart.fact_order_items
        """)).one()

        amounts_match = (
            source_amounts[0] == fact_amounts[0]
            and source_amounts[1] == fact_amounts[1]
            and fact_amounts[2] ==
                fact_amounts[0] + fact_amounts[1]
        )

        run_check(
            "Financial totals reconciliation",
            amounts_match
        )

        # ------------------------------------
        # CHECK 6: INVALID FACT MEASURES
        # ------------------------------------

        invalid_measures = conn.execute(text("""
            SELECT COUNT(*)
            FROM mart.fact_order_items
            WHERE item_price IS NULL
               OR freight_value IS NULL
               OR item_total_amount IS NULL
               OR item_price < 0
               OR freight_value < 0
        """)).scalar_one()

        run_check(
            "No invalid fact measures",
            invalid_measures == 0,
            f"({invalid_measures} invalid rows)"
        )

        # ------------------------------------
        # CHECK 7: BUSINESS DATA WARNINGS
        # ------------------------------------

        print("\n=== DATA QUALITY WARNINGS ===")

        anomalies = conn.execute(text("""
            SELECT
                COUNT(*) FILTER (
                    WHERE order_status = 'delivered'
                      AND order_delivered_customer_date
                          IS NULL
                ),
                COUNT(*) FILTER (
                    WHERE order_status = 'canceled'
                      AND order_delivered_customer_date
                          IS NOT NULL
                )
            FROM staging.orders
        """)).one()

        print(
            f"[WARN] Delivered without delivery date: "
            f"{anomalies[0]}"
        )

        print(
            f"[WARN] Canceled with delivery date: "
            f"{anomalies[1]}"
        )

        unknown_categories = conn.execute(text("""
            SELECT COUNT(*)
            FROM mart.dim_products
            WHERE product_category_name = 'Unknown'
        """)).scalar_one()

        print(
            f"[WARN] Products with unknown category: "
            f"{unknown_categories}"
        )

        zero_payments = conn.execute(text("""
            SELECT COUNT(*)
            FROM staging.order_payments
            WHERE payment_value = 0
        """)).scalar_one()

        print(
            f"[WARN] Zero-value payment rows: "
            f"{zero_payments}"
        )

    # ========================================
    # 3. FINAL VALIDATION SUMMARY
    # ========================================

    passed = sum(results)
    failed = len(results) - passed

    print("\n=== VALIDATION SUMMARY ===")
    print(f"Passed: {passed}")
    print(f"Failed: {failed}")

    if failed > 0:
        raise SystemExit(
            "Data quality validation failed!"
        )

    print("All required data quality checks passed!")


if __name__ == "__main__":
    try:
        validate_pipeline()
    finally:
        engine.dispose()
