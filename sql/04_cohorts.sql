
-- Cohort and retention analysis
-- Cohort = month of a customer's first purchase
-- Notes: 2009-12 is not a true acquisition cohort (data starts 2009-12-01)
--        2011-12 is a partial month (data ends 2011-12-09)
-- Activity is counted from the orders table only (returns are ignored)



-- STEP 1: Cohort sizes

SELECT
    DATE_FORMAT(first_purchase_date, '%Y-%m') AS cohort_month,
    COUNT(customer_id)                                  AS customers
FROM customer_summary
GROUP BY cohort_month
ORDER BY cohort_month;