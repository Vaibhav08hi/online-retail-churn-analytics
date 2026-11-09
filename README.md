# Online Retail II: Customer Churn & Retention Analytics

An end-to-end analytics project on about 1M retail transactions (Dec 2009 to Dec 2011).
A Python pipeline cleans the raw data and loads it into MySQL, where SQL analysis, dashboards
and a churn model are built on top.

**Status:** In progress. Data pipeline complete; churn definition, cohort analysis, RFM
segmentation, dashboards and ML model coming next.

## Pipeline

```
data/raw/<raw CSV>  →  clean_data.py  →  data/processed/*.csv  →  load_to_mysql.py  →  MySQL  →  validate.py
```

| Step | Script | What it does |
|---|---|---|
| 1. Clean | `src/clean_data.py` | Separates returns from sales, removes bad rows, logs every step |
| 2. Load | `src/load_to_mysql.py` | Creates the schema and loads 5 tables (customers, products, orders, order_items, returns) |
| 3. Validate | `src/validate.py` | Checks row counts, orphan rows, revenue totals and date range |

`run_pipeline.py` runs all three steps in order and stops if anything fails.

## Dataset

[Online Retail II (UCI)](https://archive.ics.uci.edu/dataset/502/online+retail+ii): transactions from a UK online gift retailer.
The raw file is not stored in this repo. Download it, save it as `data/raw/online_retail_09_10.csv`, and
make sure `RAW_PATH` at the top of `src/clean_data.py` matches that name.

## How to run

**Requirements:** Python 3.13, MySQL 8.0

1. **Clone the repo**
   ```bash
   git clone https://github.com/[your-username]/online-retail-churn-analytics.git
   cd online-retail-churn-analytics
   ```
2. **Install the dependencies**
   ```bash
   pip install -r requirements.txt
   ```
3. **Create the MySQL database and a user** (the tables are created by the pipeline)
   ```sql
   CREATE DATABASE retail_analytics;
   CREATE USER 'retail_user'@'localhost' IDENTIFIED BY 'choose_a_password';
   GRANT ALL PRIVILEGES ON retail_analytics.* TO 'retail_user'@'localhost';
   ```
4. **Set your credentials.** Copy `.env.example` to `.env` and fill in your values.
5. **Add the dataset** to `data/raw/` (see Dataset above).
6. **Run the pipeline** from the project root
   ```bash
   python run_pipeline.py
   ```

**Expected result:** the cleaning log is printed, then `Loaded ...` lines for each table, then
`ALL CHECKS PASSED`. You should see 776,577 sales rows and 18,390 return rows.

## Data cleaning summary

Raw rows: 1067371. Final: 776,577 sales rows and 18,390 return rows.

| Table | Step | Rows before | Rows after | Removed | Reason |
|---|---|---:|---:|---:|---|
| sales | Separate cancelled invoices | 1,067,371 | 1,047,877 | 19,494 | Moved to the returns table for return analysis |
| sales | Drop exact duplicates | 1,047,877 | 1,013,932 | 33,945 | Identical repeated rows |
| sales | Remove price <= 0 | 1,013,932 | 1,007,913 | 6,019 | Adjustments, not real sales |
| sales | Remove quantity <= 0 | 1,007,913 | 1,007,913 | 0 | Stock adjustments and write-offs |
| sales | Remove non-product stock codes | 1,007,913 | 1,003,214 | 4,699 | Postage, fees, manual entries |
| sales | Remove missing Customer ID | 1,003,214 | 776,577 | 226,637 | Needed for churn, cohort and RFM analysis |
| returns | Drop exact duplicates | 19,494 | 19,104 | 390 | Identical repeated rows |
| returns | Keep real product codes | 19,104 | 17,914 | 1,190 | Remove fees and manual entries |
| returns | Remove missing Customer ID | 17,914 | 17,586 | 328 | Needed for customer-level analysis |


Key decisions:
- **Returns kept separately.** Cancelled invoices (starting with "C") go into their own `returns` table for return-rate analysis, instead of being deleted.
- **Rows without a Customer ID removed (about 23% of rows).** They can't be used for churn, cohort or RFM analysis. This is a limitation: customer-level results cover only identified customers.
- **Exact duplicates dropped.** Invalid prices, non-positive quantities and non-product codes (postage, fees, manual adjustments) are removed.

## Database

| Table | Rows | Description |
|---|---|---|
| customers | 5,928 | One row per customer, with country |
| products | 4,642 | One row per stock code |
| orders | 36,594 | One row per invoice |
| order_items | 776,577 | One row per product line on an invoice |
| returns | 18,390 | One row per returned line |

## Project structure

```
├── data/
│   ├── raw/                # raw dataset (not tracked by Git)
│   ├── processed/          # cleaned CSVs (not tracked by Git)
│   └── cleaning_log.csv
├── notebooks/              # exploration and data audit
├── sql/
│   └── 01_schema.sql       # database schema
├── src/
│   ├── clean_data.py
│   ├── load_to_mysql.py
│   └── validate.py
├── run_pipeline.py
├── requirements.txt
└── .env.example
```

## Roadmap

- [x] Data audit and cleaning
- [x] Python to MySQL pipeline with validation
- [ ] Churn definition and sensitivity analysis
- [ ] SQL cohort and retention analysis
- [ ] RFM segmentation and customer lifetime value
- [ ] Power BI and Tableau dashboards
- [ ] Churn prediction model

## Tools

Python (Pandas, SQLAlchemy, Scikit-learn), MySQL, Power BI, Tableau, Git