import os , sys , pandas as pd
from dotenv import load_dotenv
from urllib.parse import quote_plus
from sqlalchemy import create_engine, text

# Make "src" importable even when running: python src/validate.py
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from src.load_to_mysql import get_engine ,SALES_PATH , RETURNS_PATH


def scalar ( engine , sql) :
    with engine.connect() as connection:
        query = text(sql)
        result = connection.execute(query)
        value = result.scalar()
        # Fetch the single row scalar value
        return float(value) if value is not None else None

def run_checks(engine) :
    sales_revenue = pd.read_csv(SALES_PATH , usecols= ["Revenue"])["Revenue"]
    n_sales = len(sales_revenue)
    n_return = len(pd.read_csv(RETURNS_PATH, usecols=[0]))

    results = []

    def add(name , passed , detail ):
        results.append((name , bool(passed) , detail))

    #1. row count match the csv file 
    db_item = scalar(engine , "SELECT COUNT(*) FROM order_items")
    add("order item count matches the csv file" , db_item == n_sales , f"MySQL = {db_item:,.0f} | CSV = {n_sales:,}")

    db_return = scalar(engine , "SELECT COUNT(*) FROM returns")
    add("return count matches the csv file" , db_return == n_return ,f"MySQL = {db_return:,.0f} | CSV = {n_return:,}" )

    #2. No missing customer Ids 
    null_order = scalar(engine , "SELECT COUNT(*) FROM orders WHERE customer_id IS NULL")
    add("NO null customer id in order", null_order == 0 , f"found = {null_order:,.0f}")

    null_returns =scalar(engine , "SELECT COUNT(*) FROM returns WHERE customer_id IS NULL")
    add("NO null customer id in returns", null_returns == 0 , f"found = {null_returns:,.0f}")

    # 3. No orphan rows
    orphan_items = scalar(engine, """
        SELECT COUNT(*) FROM order_items oi
        LEFT JOIN orders o ON oi.invoice_no = o.invoice_no
        WHERE o.invoice_no IS NULL""")
    add("no orphan order_items", orphan_items == 0, f"found={orphan_items:,.0f}")

    orphan_orders = scalar(engine, """
        SELECT COUNT(*) FROM orders o
        LEFT JOIN customers c ON o.customer_id = c.customer_id
        WHERE c.customer_id IS NULL""")
    add("no orphan orders", orphan_orders == 0, f"found={orphan_orders:,.0f}")

    # 4. Revenue in MySQL equals revenue in the CSV (small rounding tolerance)
    db_revenue = scalar(engine, "SELECT SUM(revenue) FROM order_items")
    csv_revenue = float(sales_revenue.sum())
    add("total revenue matches", abs(db_revenue - csv_revenue) < 1,
        f"MySQL={db_revenue:,.2f} | CSV={csv_revenue:,.2f}")

    # 5. Returns values are not negative
    min_return = scalar(engine, "SELECT MIN(return_value) FROM returns")
    add("return_value is never negative", min_return >= 0, f"min={min_return:,.2f}")

    # 6. Date range looks right
    min_year = scalar(engine, "SELECT YEAR(MIN(invoice_date)) FROM orders")
    max_year = scalar(engine, "SELECT YEAR(MAX(invoice_date)) FROM orders")
    add("date range is 2009 to 2011", min_year == 2009 and max_year == 2011,
        f"{min_year:.0f} to {max_year:.0f}")

    # 7. No duplicate invoices
    total_orders = scalar(engine, "SELECT COUNT(*) FROM orders")
    unique_orders = scalar(engine, "SELECT COUNT(DISTINCT invoice_no) FROM orders")
    add("no duplicate invoices", total_orders == unique_orders,
        f"rows={total_orders:,.0f} | unique={unique_orders:,.0f}")

    return results

def print_report(results) :
    failures = 0 
    for name, passed, detail in results:
        print(f"{'PASS' if passed else 'FAIL'} - {name}")
        if not passed:
            print(f"       {detail}")
            failures += 1

    print()
    if failures == 0:
        print("ALL CHECKS PASSED")
    else:
        print(f"{failures} CHECK(S) FAILED")
    return failures == 0

def main():
    engine = get_engine()
    results = run_checks(engine)
    return print_report(results)


if __name__ == "__main__":
    if not main():
        sys.exit(1)