
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


-- STEP 4A: Revenue by cohort and month since start


-- Revenue per customer per calendar month (sales only)
CREATE OR REPLACE VIEW customer_month_revenue AS
SELECT
    o.customer_id,
    CONCAT(YEAR(o.invoice_date), '-', LPAD(MONTH(o.invoice_date), 2, '0')) AS active_month,
    ROUND(SUM(oi.revenue), 2)                                              AS revenue
FROM orders o
JOIN order_items oi ON oi.invoice_no = o.invoice_no
GROUP BY o.customer_id, active_month;

-- Revenue by cohort, months 0 to 12, excluding the partial month 2011-12
CREATE OR REPLACE VIEW cohort_revenue AS
SELECT
    t.cohort_month,
    t.months_since_start,
    cs.cohort_size,
    t.revenue,
    ROUND(t.revenue / cs.cohort_size, 2) AS revenue_per_customer,
    ROUND(SUM(t.revenue) OVER (PARTITION BY t.cohort_month
                               ORDER BY t.months_since_start) / cs.cohort_size, 2)
                                         AS cumulative_revenue_per_customer
FROM (
    SELECT
        cm.cohort_month,
        cm.months_since_start,
        ROUND(SUM(r.revenue), 2) AS revenue
    FROM customer_months cm
    JOIN customer_month_revenue r
      ON r.customer_id = cm.customer_id AND r.active_month = cm.active_month
    WHERE cm.months_since_start BETWEEN 0 AND 12
      AND cm.active_month < '2011-12'
    GROUP BY cm.cohort_month, cm.months_since_start
) t
JOIN (
    SELECT cohort_month, COUNT(*) AS cohort_size
    FROM customer_months
    WHERE months_since_start = 0
    GROUP BY cohort_month
) cs ON cs.cohort_month = t.cohort_month;


-- Checks for part A

-- 1. Total revenue must equal 17068567.97
SELECT ROUND(SUM(revenue), 2) AS total_revenue FROM customer_month_revenue;

-- 2. Same total through the join to customer_months, with no month filters
SELECT ROUND(SUM(r.revenue), 2) AS total_via_join
FROM customer_months cm
JOIN customer_month_revenue r
  ON r.customer_id = cm.customer_id AND r.active_month = cm.active_month;

-- 3. Revenue inside cohort_revenue (lower than the total: no 2011-12, no month 13+)
SELECT ROUND(SUM(revenue), 2) AS revenue_in_view FROM cohort_revenue;

-- 4. Cumulative revenue must never go down within a cohort (expect 0)
SELECT COUNT(*) AS decreasing_rows
FROM (
    SELECT cumulative_revenue_per_customer AS cum,
           LAG(cumulative_revenue_per_customer) OVER (PARTITION BY cohort_month
                                                      ORDER BY months_since_start) AS prev_cum
    FROM cohort_revenue
) x
WHERE cum < prev_cum;

-- 5. Month 0 revenue per customer must be positive (expect 0)
SELECT COUNT(*) AS bad_month_0
FROM cohort_revenue
WHERE months_since_start = 0 AND revenue_per_customer <= 0;

-- 6. One cohort across months 0 to 12
SELECT * FROM cohort_revenue
WHERE cohort_month = '2010-01'
ORDER BY months_since_start;


-- STEP 4B: Repeat purchase rate by cohort
-- Repeat = two or more different order days
-- The 90-day rate is only shown for cohorts through 2011-08, because later cohorts
-- have not had 90 full days of data (the data ends 2011-12-09)


CREATE OR REPLACE VIEW customer_order_days AS
SELECT customer_id, COUNT(DISTINCT DATE(invoice_date)) AS order_days
FROM orders
GROUP BY customer_id;

CREATE OR REPLACE VIEW cohort_repeat_rate AS
SELECT
    cohort_month,
    COUNT(*)                                       AS cohort_size,
    SUM(is_repeat)                                 AS repeat_customers,
    COUNT(*) - SUM(is_repeat)                      AS one_time_customers,
    ROUND(100 * AVG(is_repeat), 2)                 AS repeat_rate_pct,
    CASE WHEN cohort_month <= '2011-08'
         THEN ROUND(100 * AVG(repeat_90d), 2) END  AS repeat_within_90d_pct
FROM (
    SELECT
        DATE_FORMAT(cs.first_purchase_date, '%Y-%m')  AS cohort_month,
        cs.customer_id,
        (cod.order_days >= 2)                         AS is_repeat,
        (r90.customer_id IS NOT NULL)                 AS repeat_90d
    FROM customer_summary cs
    JOIN customer_order_days cod ON cod.customer_id = cs.customer_id
    LEFT JOIN (
        SELECT DISTINCT o.customer_id
        FROM orders o
        JOIN customer_summary s ON s.customer_id = o.customer_id
        WHERE DATE(o.invoice_date) > s.first_purchase_date
          AND DATE(o.invoice_date) <= s.first_purchase_date + INTERVAL 90 DAY
    ) r90 ON r90.customer_id = cs.customer_id
) x
GROUP BY cohort_month;


-- Checks for part B

-- 1. Totals (expect 5852 customers, 4179 repeat, 1673 one-time, about 71.41%)
SELECT
    SUM(cohort_size)                                  AS customers,
    SUM(repeat_customers)                             AS repeat_customers,
    SUM(one_time_customers)                           AS one_time_customers,
    ROUND(100 * SUM(repeat_customers) / SUM(cohort_size), 2) AS overall_repeat_rate_pct
FROM cohort_repeat_rate;

-- 2. Repeat + one-time must equal cohort size for every cohort (expect 0 rows)
SELECT cohort_month
FROM cohort_repeat_rate
WHERE repeat_customers + one_time_customers <> cohort_size;

-- 3. The 90-day rate must be NULL after 2011-08
SELECT cohort_month, repeat_within_90d_pct
FROM cohort_repeat_rate
WHERE cohort_month >= '2011-08'
ORDER BY cohort_month;

-- 4. Full table
SELECT * FROM cohort_repeat_rate ORDER BY cohort_month;