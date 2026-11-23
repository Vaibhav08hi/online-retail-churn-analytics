
-- Cohort and retention analysis
-- Cohort = month of a customer's first purchase
-- Notes: 2009-12 is not a true acquisition cohort (data starts 2009-12-01)
--        2011-12 is a partial month (data ends 2011-12-09)
-- Activity is counted from the orders table only (returns are ignored)



-- STEP 1: Cohort sizes

SELECT
    DATE_FORMAT(first_purchase_date, '%Y-%m') AS cohort_month,
    COUNT(customer_id) AS customers
FROM customer_summary
GROUP BY cohort_month
ORDER BY cohort_month;

-- STEP 2: One row per customer per month in which they were active

CREATE OR REPLACE VIEW customer_months AS
SELECT
    am.customer_id,
    DATE_FORMAT(cs.first_purchase_date, '%Y-%m')        AS cohort_month,
    CONCAT(am.yr, '-', LPAD(am.mo, 2, '0'))             AS active_month,
    (am.yr * 12 + am.mo)
      - (YEAR(cs.first_purchase_date) * 12 + MONTH(cs.first_purchase_date)) AS months_since_start
FROM (
    SELECT DISTINCT
        customer_id,
        YEAR(invoice_date)  AS yr,
        MONTH(invoice_date) AS mo
    FROM orders
) am
JOIN customer_summary cs ON cs.customer_id = am.customer_id;

-- Checks for step 2

-- 1. Month 0 rows (expect 5852, one per customer)
SELECT COUNT(*) AS month_0_rows
FROM customer_months
WHERE months_since_start = 0;

-- 2. Range of months_since_start (expect min 0, max 24)
SELECT MIN(months_since_start) AS min_months, MAX(months_since_start) AS max_months
FROM customer_months;

-- 3. Total rows in the view
SELECT COUNT(*) AS total_rows FROM customer_months;

-- 4. Month 0 rows per cohort must equal the cohort sizes from step 1
SELECT cohort_month, COUNT(*) AS customers
FROM customer_months
WHERE months_since_start = 0
GROUP BY cohort_month
ORDER BY cohort_month;

-- 5. Any customer without a month 0 row? (expect 0 rows)
SELECT customer_id
FROM customer_months
GROUP BY customer_id
HAVING MIN(months_since_start) <> 0;

-- 6. Hand check: look at one customer here, then compare with their invoices
SELECT * FROM customer_months WHERE customer_id = (SELECT MIN(customer_id) FROM customer_summary) ORDER BY active_month;

SELECT customer_id, invoice_no, invoice_date
FROM orders
WHERE customer_id = (SELECT MIN(customer_id) FROM customer_summary)
ORDER BY invoice_date;


-- STEP 3: Retention by cohort and month since start (long format)
-- Months 0 to 12 only
-- December 2011 is excluded as an active month (partial month, data ends 2011-12-09)
-- so the 2011-12 cohort drops out and each cohort stops at 2011-11

CREATE OR REPLACE VIEW cohort_retention AS
SELECT
    cm.cohort_month,
    cm.months_since_start,
    cs.cohort_size,
    COUNT(DISTINCT cm.customer_id)                                       AS active_customers,
    ROUND(100 * COUNT(DISTINCT cm.customer_id) / cs.cohort_size, 2)      AS retention_pct
FROM customer_months cm
JOIN (
    SELECT cohort_month, COUNT(*) AS cohort_size
    FROM customer_months
    WHERE months_since_start = 0
    GROUP BY cohort_month
) cs ON cs.cohort_month = cm.cohort_month
WHERE cm.months_since_start BETWEEN 0 AND 12
  AND cm.active_month < '2011-12'
GROUP BY cm.cohort_month, cm.months_since_start, cs.cohort_size;


-- Checks for step 3

-- 1. Month 0 must be 100% for every cohort (expect 0 rows)
SELECT cohort_month, retention_pct
FROM cohort_retention
WHERE months_since_start = 0 AND retention_pct <> 100;

-- 2. Retention must stay between 0 and 100
SELECT MIN(retention_pct) AS min_pct, MAX(retention_pct) AS max_pct
FROM cohort_retention;

-- 3. Number of cohorts and total rows (expect 24 cohorts, 234 rows)
SELECT COUNT(DISTINCT cohort_month) AS cohorts, COUNT(*) AS total_rows
FROM cohort_retention;

-- 4. Triangle shape: cells per cohort (13 for the first 12 cohorts, then 12, 11 ... 1)
SELECT cohort_month, COUNT(*) AS cells, MAX(months_since_start) AS last_month
FROM cohort_retention
GROUP BY cohort_month
ORDER BY cohort_month;

-- 5. Cohort sizes must match step 1 (the 2011-12 cohort is missing here)
SELECT SUM(cohort_size) AS total_in_view
FROM (SELECT DISTINCT cohort_month, cohort_size FROM cohort_retention) t;

-- 6. Look at one cohort across months 0 to 12
SELECT * FROM cohort_retention
WHERE cohort_month = '2010-01'
ORDER BY months_since_start;