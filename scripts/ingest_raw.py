import os
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import (
    create_engine,
    text,
    Table,
    Column,
    MetaData,
    Text,
)
from sqlalchemy.engine import URL


# ==================================================
# 1. Project configuration
# ==================================================

BASE_DIR = Path(__file__).resolve().parents[1]
RAW_DIR = BASE_DIR / "data"  

load_dotenv(BASE_DIR / ".env")

FILES = {
    "customers": "olist_customers_dataset.csv",
    "orders": "olist_orders_dataset.csv",
    "order_items": "olist_order_items_dataset.csv",
    "products": "olist_products_dataset.csv",
    "sellers": "olist_sellers_dataset.csv",
    "order_payments": "olist_order_payments_dataset.csv",
    "order_reviews": "olist_order_reviews_dataset.csv",
}


# ==================================================
# 2. PostgreSQL connection
# ==================================================

def get_engine():
    password = os.getenv("DB_PASSWORD")

    if not password:
        raise ValueError("DB_PASSWORD is missing in .env")

    url = URL.create(
        drivername="postgresql+psycopg2",
        username=os.getenv("DB_USER", "postgres"),
        password=password,
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "5432")),
        database=os.getenv("DB_NAME", "ecommerce_dw"),
    )

    return create_engine(url, pool_pre_ping=True)


# ==================================================
# 3. Data ingestion
# ==================================================

def ingest_csv(engine, table_name, filename):

    file_path = RAW_DIR / filename

    # Read column names without loading the dataset
    header = pd.read_csv(
        file_path,
        nrows=0,
        encoding="utf-8-sig"
    )

    # Keep raw columns as TEXT
    table = Table(
        table_name,
        MetaData(),
        *[Column(col, Text) for col in header.columns],
        schema="raw"
    )

    total_rows = 0

    # Transaction: commit only when loading succeeds
    with engine.begin() as conn:

        # Create table if it does not exist
        table.create(bind=conn, checkfirst=True)

        # Full refresh: prevent duplicate rows on reruns
        conn.execute(
            text(f"TRUNCATE TABLE raw.{table_name}")
        )

        # Read and insert data in chunks
        chunks = pd.read_csv(
            file_path,
            dtype=str,
            keep_default_na=False,
            encoding="utf-8-sig",
            chunksize=2000
        )

        for chunk in chunks:

            chunk.to_sql(
                name=table_name,
                con=conn,
                schema="raw",
                if_exists="append",
                index=False,
                chunksize=1000
            )

            total_rows += len(chunk)

        # Validate loaded row count
        db_rows = conn.execute(
            text(f"SELECT COUNT(*) FROM raw.{table_name}")
        ).scalar_one()

        if db_rows != total_rows:
            raise ValueError(
                f"Row count mismatch in {table_name}"
            )

    print(f"[OK] {table_name}: {total_rows:,} rows")
    return total_rows


# ==================================================
# 4. Main pipeline
# ==================================================

def main():
    print("\n=== INGESTION DEBUG ===", flush=True)
    print("Script:", Path(__file__).resolve(), flush=True)
    print("RAW_DIR:", RAW_DIR, flush=True)
    print("Directory exists:", RAW_DIR.is_dir(), flush=True)
    print(
    "Available CSV files:",
    [p.name for p in RAW_DIR.glob("*.csv")],
    flush=True
)
    # Check all source files before loading
    missing_files = [
        filename
        for filename in FILES.values()
        if not (RAW_DIR / filename).is_file()
    ]

    if missing_files:
        raise FileNotFoundError(
            f"Missing CSV files: {missing_files}"
        )

    engine = get_engine()

    try:
        # Verify database connection
        with engine.connect() as conn:
            db_name = conn.execute(
                text("SELECT current_database()")
            ).scalar_one()

        if db_name != "ecommerce_dw":
            raise ValueError(
                f"Unexpected database: {db_name}"
            )

        print(f"Connected to database: {db_name}")
        print("Starting data ingestion...\n")

        total = 0

        for table_name, filename in FILES.items():
            total += ingest_csv(
                engine,
                table_name,
                filename
            )

        print("\nData ingestion completed!")
        print(f"Total rows loaded: {total:,}")

    finally:
        engine.dispose()


if __name__ == "__main__":
    main()