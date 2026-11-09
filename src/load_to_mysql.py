import os
from urllib.parse import quote_plus

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv()

SALES_PATH = "notebooks/data/processed/sales_clean.csv"
RETURNS_PATH = "notebooks/data/processed/returns_clean.csv"
SCHEMA_PATH = "sql/01_schema.sql"
CHUNK = 5000


def get_engine():
    user = os.getenv("DB_USER")
    password = quote_plus(os.getenv("DB_PASSWORD"))
    host = os.getenv("DB_HOST", "localhost")
    db = os.getenv("DB_NAME")
    return create_engine(f"mysql+pymysql://{user}:{password}@{host}/{db}")


def run_schema(engine, path):
    with open(path, encoding="utf-8") as f:
        statements = [s.strip() for s in f.read().split(";") if s.strip()]
    with engine.begin() as conn:
        for stmt in statements:
            conn.execute(text(stmt))
    print("Schema created")


def normalize_columns(df):
    """Rename columns so both dataset versions work."""
    return df.rename(columns={
        "InvoiceNo": "Invoice",
        "CustomerID": "Customer ID",
        "UnitPrice": "Price",
    })


def most_common(series):
    mode = series.dropna().mode()
    return mode.iloc[0] if len(mode) else None


def load_csvs():
    sales = normalize_columns(pd.read_csv(SALES_PATH, parse_dates=["InvoiceDate"]))
    returns = normalize_columns(pd.read_csv(RETURNS_PATH, parse_dates=["InvoiceDate"]))

    for df in (sales, returns):
        df["Invoice"] = df["Invoice"].astype(str).str.strip()
        df["StockCode"] = df["StockCode"].astype(str).str.strip()
        df["Customer ID"] = df["Customer ID"].astype(int)

    sales["Revenue"] = sales["Revenue"].round(2)
    returns["ReturnValue"] = returns["ReturnValue"].round(2)
    return sales, returns


def build_tables(sales, returns):
    both = pd.concat([sales, returns], ignore_index=True)

    customers = (
        both.groupby("Customer ID")["Country"].agg(most_common)
        .reset_index()
        .rename(columns={"Customer ID": "customer_id", "Country": "country"})
    )

    products = (
        both.groupby("StockCode")["Description"].agg(most_common)
        .reset_index()
        .rename(columns={"StockCode": "stock_code", "Description": "description"})
    )
    products["description"] = products["description"].str.slice(0, 255)

    orders = (
        sales.drop_duplicates(subset="Invoice")[["Invoice", "Customer ID", "InvoiceDate", "Country"]]
        .rename(columns={"Invoice": "invoice_no", "Customer ID": "customer_id",
                         "InvoiceDate": "invoice_date", "Country": "country"})
    )

    order_items = (
        sales[["Invoice", "StockCode", "Quantity", "Price", "Revenue"]]
        .rename(columns={"Invoice": "invoice_no", "StockCode": "stock_code",
                         "Quantity": "quantity", "Price": "unit_price", "Revenue": "revenue"})
    )

    ret = (
        returns[["Invoice", "Customer ID", "StockCode", "InvoiceDate",
                 "Quantity", "Price", "ReturnValue"]]
        .rename(columns={"Invoice": "invoice_no", "Customer ID": "customer_id",
                         "StockCode": "stock_code", "InvoiceDate": "invoice_date",
                         "Quantity": "quantity", "Price": "unit_price",
                         "ReturnValue": "return_value"})
    )

    # Parents first, children after
    return [
        ("customers", customers),
        ("products", products),
        ("orders", orders),
        ("order_items", order_items),
        ("returns", ret),
    ]


def main():
    engine = get_engine()
    run_schema(engine, SCHEMA_PATH)

    sales, returns = load_csvs()
    print(f"Read {len(sales):,} sales rows and {len(returns):,} return rows")

    for name, frame in build_tables(sales, returns):
        frame.to_sql(name, engine, if_exists="append", index=False,
                     chunksize=CHUNK, method="multi")
        print(f"Loaded {name}: {len(frame):,} rows")

    print("Done")


if __name__ == "__main__":
    main()