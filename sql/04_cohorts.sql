
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