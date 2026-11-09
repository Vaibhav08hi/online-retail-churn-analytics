import os
import sys

import pandas as pd

# ---------- Paths (relative to the project root) ----------
RAW_PATH = "data/raw/online_retail_09_10.csv"   # change to your exact raw file name
SALES_OUT = "data/processed/sales_clean.csv"
RETURNS_OUT = "data/processed/returns_clean.csv"
LOG_OUT = "data/cleaning_log.csv"

log = []


def log_step(table, step, before, after, reason):
    log.append({
        "Table": table,
        "Step": step,
        "Rows before": before,
        "Rows after": after,
        "Removed": before - after,
        "Reason": reason,
    })


def load_raw(path=RAW_PATH):
    if not os.path.exists(path):
        print(f"dataset file not found: {path}")
        print("Download the Online Retail II dataset (UCI or Kaggle), place the CSV in data/raw/,")
        print("and set RAW_PATH at the top of src/clean_data.py to its exact file name.")
        sys.exit(1)

    dtypes = {"Invoice": str, "InvoiceNo": str, "StockCode": str}
    try:
        df = pd.read_csv(path, dtype=dtypes, parse_dates=["InvoiceDate"])
    except UnicodeDecodeError:
        df = pd.read_csv(path, dtype=dtypes, parse_dates=["InvoiceDate"], encoding="latin-1")

    df = df.rename(columns={"InvoiceNo": "Invoice", "UnitPrice": "Price", "CustomerID": "Customer ID"})
    df["Invoice"] = df["Invoice"].astype(str).str.strip()
    df["StockCode"] = df["StockCode"].astype(str).str.strip()

    print(f"Loaded {len(df):,} rows | {df['InvoiceDate'].min()} to {df['InvoiceDate'].max()}")
    return df


def clean_sales(sales):
    n = len(sales)

    before = len(sales)
    sales = sales.drop_duplicates()
    log_step("sales", "Drop exact duplicates", before, len(sales), "Identical repeated rows")

    before = len(sales)
    sales = sales[sales["Price"] > 0]
    log_step("sales", "Remove price <= 0", before, len(sales), "Adjustments, not real sales")

    before = len(sales)
    sales = sales[sales["Quantity"] > 0]
    log_step("sales", "Remove quantity <= 0", before, len(sales), "Stock adjustments and write-offs")

    before = len(sales)
    sales = sales[sales["StockCode"].str.match(r"^\d{5}")]
    log_step("sales", "Remove non-product stock codes", before, len(sales), "Postage, fees, manual entries")

    before = len(sales)
    sales = sales.dropna(subset=["Customer ID"])
    log_step("sales", "Remove missing Customer ID", before, len(sales), "Needed for churn, cohort and RFM analysis")

    sales = sales.copy()
    sales["Customer ID"] = sales["Customer ID"].astype(int)
    sales["Revenue"] = (sales["Quantity"] * sales["Price"]).round(2)
    return sales


def clean_returns(returns):
    before = len(returns)
    returns = returns.drop_duplicates()
    log_step("returns", "Drop exact duplicates", before, len(returns), "Identical repeated rows")

    before = len(returns)
    returns = returns[returns["StockCode"].str.match(r"^\d{5}")]
    log_step("returns", "Keep real product codes", before, len(returns), "Remove fees and manual entries")

    before = len(returns)
    returns = returns.dropna(subset=["Customer ID"])
    log_step("returns", "Remove missing Customer ID", before, len(returns), "Needed for customer-level analysis")

    returns = returns.copy()
    returns["Customer ID"] = returns["Customer ID"].astype(int)
    returns["ReturnValue"] = (returns["Quantity"].abs() * returns["Price"]).round(2)
    return returns


def sanity_checks(sales, returns):
    checks = {
        "sales: no missing Customer ID": sales["Customer ID"].isnull().sum() == 0,
        "sales: all quantities > 0": (sales["Quantity"] > 0).all(),
        "sales: all prices > 0": (sales["Price"] > 0).all(),
        "sales: no cancelled invoices": not sales["Invoice"].str.startswith(("C", "c")).any(),
        "sales: has Revenue column": "Revenue" in sales.columns,
        "returns: no missing Customer ID": returns["Customer ID"].isnull().sum() == 0,
        "returns: all quantities < 0": (returns["Quantity"] < 0).all(),
        "returns: has ReturnValue, no Revenue": "ReturnValue" in returns.columns and "Revenue" not in returns.columns,
    }
    failed = [name for name, ok in checks.items() if not ok]
    for name, ok in checks.items():
        print("PASS" if ok else "FAIL", "-", name)
    if failed:
        print("\nSanity checks failed, nothing was saved.")
        sys.exit(1)


def main():
    df = load_raw()

    # Split first, so cancellations are not removed by the quantity filter
    is_cancelled = df["Invoice"].str.startswith(("C", "c"))
    returns = df[is_cancelled].copy()
    sales = df[~is_cancelled].copy()
    log_step("sales", "Separate cancelled invoices", len(df), len(sales),
             "Moved to the returns table for return analysis")

    sales = clean_sales(sales)
    returns = clean_returns(returns)

    print()
    sanity_checks(sales, returns)

    os.makedirs(os.path.dirname(SALES_OUT), exist_ok=True)
    sales.to_csv(SALES_OUT, index=False)
    returns.to_csv(RETURNS_OUT, index=False)

    log_df = pd.DataFrame(log)
    log_df.to_csv(LOG_OUT, index=False)

    print("\nCleaning log:")
    print(log_df.to_string(index=False))
    print(f"\nSaved {len(sales):,} sales rows and {len(returns):,} return rows")


if __name__ == "__main__":
    main()