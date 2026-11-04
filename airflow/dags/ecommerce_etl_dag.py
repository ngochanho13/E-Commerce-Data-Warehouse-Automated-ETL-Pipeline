
import os
import sys
import subprocess
from datetime import timedelta
from pathlib import Path

import pendulum
import psycopg2
from dotenv import dotenv_values
from airflow.sdk import dag, task


# =============================================
# 1. CONFIGURATION
# =============================================

PROJECT_DIR = Path("/opt/airflow/project")
SCRIPTS_DIR = PROJECT_DIR / "scripts"
SQL_DIR = PROJECT_DIR / "sql"
ENV_FILE = PROJECT_DIR / ".env"

DB_HOST = "host.docker.internal"


def get_db_config():
    config = dotenv_values(ENV_FILE)

    required = ["DB_NAME", "DB_USER", "DB_PASSWORD"]
    missing = [key for key in required if not config.get(key)]

    if missing:
        raise ValueError(f"Missing database settings: {missing}")

    return config


# =============================================
# 2. PYTHON SCRIPT EXECUTION
# =============================================

def execute_python(script_name):
    script_path = SCRIPTS_DIR / script_name

    if not script_path.is_file():
        raise FileNotFoundError(script_path)

    config = get_db_config()

    # Pass DB settings only to the ETL subprocess.
    # Do not change the Airflow worker environment.
    env = os.environ.copy()

    for key in ["DB_PORT", "DB_NAME", "DB_USER", "DB_PASSWORD"]:
        if config.get(key):
            env[key] = config[key]

    env["DB_HOST"] = DB_HOST

    print(f"Running Python script: {script_name}", flush=True)

    subprocess.run(
        [sys.executable, str(script_path)],
        cwd=str(PROJECT_DIR),
        env=env,
        check=True
    )

    print(f"Completed: {script_name}", flush=True)


# =============================================
# 3. SQL EXECUTION
# =============================================

def execute_sql(filename):
    sql_path = SQL_DIR / filename

    if not sql_path.is_file():
        raise FileNotFoundError(sql_path)

    config = get_db_config()

    conn = psycopg2.connect(
        host=DB_HOST,
        port=config.get("DB_PORT", "5432"),
        dbname=config["DB_NAME"],
        user=config["DB_USER"],
        password=config["DB_PASSWORD"],
        connect_timeout=10
    )

    try:
        # Each SQL file contains BEGIN and COMMIT.
        conn.autocommit = True

        with conn.cursor() as cursor:
            cursor.execute("SELECT current_database()")
            current_db = cursor.fetchone()[0]

            if current_db != "ecommerce_dw":
                raise RuntimeError(
                    f"Unexpected database: {current_db}"
                )

            sql_script = sql_path.read_text(
                encoding="utf-8-sig"
            )

            print(f"Executing SQL: {filename}", flush=True)

            cursor.execute(sql_script)

        print(f"Completed: {filename}", flush=True)

    except Exception:
        # Roll back an explicit BEGIN if the SQL fails.
        with conn.cursor() as cursor:
            cursor.execute("ROLLBACK")
        raise

    finally:
        conn.close()


# =============================================
# 4. AIRFLOW DAG
# =============================================

@dag(
    dag_id="ecommerce_etl_pipeline",
    description="End-to-end E-Commerce Data Warehouse ETL",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    schedule=None,
    catchup=False,
    max_active_runs=1,
    tags=["data-engineering", "etl", "ecommerce"],
)
def ecommerce_etl_pipeline():

    @task(retries=1, retry_delay=timedelta(minutes=1))
    def ingest_raw():
        execute_python("ingest_raw.py")

    @task(retries=1, retry_delay=timedelta(minutes=1))
    def transform_customers_orders():
        execute_sql("02_create_staging.sql")

    @task(retries=1, retry_delay=timedelta(minutes=1))
    def transform_remaining_tables():
        execute_sql("03_complete_staging.sql")

    @task(retries=1, retry_delay=timedelta(minutes=1))
    def build_dimensions():
        execute_sql("04_create_dimensions.sql")

    @task(retries=1, retry_delay=timedelta(minutes=1))
    def build_fact_order_items():
        execute_sql("05_create_fact_order_items.sql")

    @task(retries=1, retry_delay=timedelta(minutes=1))
    def validate_data_quality():
        execute_python("validate_pipeline.py")

    @task(retries=1, retry_delay=timedelta(minutes=1))
    def build_analytics_views():
        execute_sql("06_create_analytics_views.sql")

    (
        ingest_raw()
        >> transform_customers_orders()
        >> transform_remaining_tables()
        >> build_dimensions()
        >> build_fact_order_items()
        >> build_analytics_views()
        >> validate_data_quality()
)


ecommerce_etl_pipeline()
