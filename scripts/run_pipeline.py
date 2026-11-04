
import os
import sys
import time
import subprocess
from pathlib import Path

import psycopg2
from dotenv import load_dotenv


# =============================================
# 1. CONFIGURATION
# =============================================

BASE_DIR = Path(__file__).resolve().parents[1]
SQL_DIR = BASE_DIR / "sql"

load_dotenv(BASE_DIR / ".env")

SQL_FILES = [
    "02_create_staging.sql",
    "03_complete_staging.sql",
    "04_create_dimensions.sql",
    "05_create_fact_order_items.sql",
    "06_create_analytics_views.sql",
]


# =============================================
# 2. RUN PYTHON SCRIPTS
# =============================================

def run_python(script_name):

    print(f"\n[START] {script_name}", flush=True)

    subprocess.run(
        [
            sys.executable,
            str(BASE_DIR / "scripts" / script_name)
        ],
        check=True,
        cwd=BASE_DIR
    )

    print(f"[SUCCESS] {script_name}", flush=True)


# =============================================
# 3. EXECUTE SQL FILES
# =============================================

def run_sql(filename):

    file_path = SQL_DIR / filename

    if not file_path.is_file():
        raise FileNotFoundError(
            f"SQL file not found: {file_path}"
        )

    sql_script = file_path.read_text(
        encoding="utf-8-sig"
    )

    print(f"\n[START] {filename}", flush=True)

    conn = psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "5432")),
        dbname=os.getenv("DB_NAME", "ecommerce_dw"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD"),
    )

    try:
        # SQL files already contain BEGIN / COMMIT
        conn.autocommit = True

        with conn.cursor() as cursor:

            cursor.execute(
                "SELECT current_database()"
            )

            current_db = cursor.fetchone()[0]

            if current_db != "ecommerce_dw":
                raise RuntimeError(
                    f"Unexpected database: {current_db}"
                )

            cursor.execute(sql_script)

        print(f"[SUCCESS] {filename}", flush=True)

    except Exception:

        with conn.cursor() as cursor:
            cursor.execute("ROLLBACK;")

        raise

    finally:
        conn.close()

# =============================================
# 4. MAIN PIPELINE
# =============================================

def main():

    start_time = time.perf_counter()

    print("=" * 50)
    print("E-COMMERCE DATA ENGINEERING PIPELINE")
    print("=" * 50)

    # Step 1: Data Ingestion
    print("\n=== STEP 1: DATA INGESTION ===")

    run_python("ingest_raw.py")

    # Step 2: SQL Transformations
    print("\n=== STEP 2: SQL TRANSFORMATIONS ===")

    for filename in SQL_FILES:
        run_sql(filename)

    # Step 3: Data Quality Validation
    print("\n=== STEP 3: DATA QUALITY ===")

    run_python("validate_pipeline.py")

    duration = time.perf_counter() - start_time

    print("\n" + "=" * 50)
    print("PIPELINE COMPLETED SUCCESSFULLY")
    print(f"Execution time: {duration:.2f} seconds")
    print("=" * 50)


if __name__ == "__main__":

    try:
        main()

    except Exception as error:

        print("\n[FAILED] Pipeline stopped.")
        print(f"Error: {error}")

        sys.exit(1)