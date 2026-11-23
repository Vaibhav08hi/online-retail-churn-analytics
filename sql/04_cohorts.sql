
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
