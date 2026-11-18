-- latest date - '2011-12-09'
-- earliest invoice_date - '2009-12-01'
-- Reference date: day after the last invoice in the data - '2011-12-10'

CREATE OR REPLACE VIEW customer_summary AS
SELECT
    o.customer_id,
    DATE(MIN(o.invoice_date))                          AS first_purchase_date,
    DATE(MAX(o.invoice_date))                          AS last_purchase_date,
    COUNT(DISTINCT o.invoice_no)                       AS num_orders,
    ROUND(SUM(oi.revenue), 2)                          AS total_spend,
    ROUND(SUM(oi.revenue) / COUNT(DISTINCT o.invoice_no), 2) AS avg_order_value,
    DATEDIFF(r.ref_date, DATE(MAX(o.invoice_date)))    AS days_since_last_purchase,
    DATEDIFF(DATE(MAX(o.invoice_date)), DATE(MIN(o.invoice_date))) AS customer_lifetime_days
FROM orders o
JOIN order_items oi ON oi.invoice_no = o.invoice_no
CROSS JOIN (
    SELECT DATE(MAX(invoice_date)) + INTERVAL 1 DAY AS ref_date
    FROM orders
) r
GROUP BY o.customer_id, r.ref_date;

CREATE OR REPLACE VIEW order_gaps AS
SELECT
    customer_id,
    order_date,
    prev_order_date,
    DATEDIFF(order_date, prev_order_date) AS gap_days
FROM (
    SELECT
        customer_id,
        order_date,
        LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS prev_order_date
    FROM (
        SELECT DISTINCT customer_id, DATE(invoice_date) AS order_date
        FROM orders
    ) AS order_days
) AS with_prev
WHERE prev_order_date IS NOT NULL;


-- Percentiles of the gaps
SELECT
    MAX(total)                                              AS total_gaps,
    MAX(CASE WHEN rn = CEIL(0.50 * total) THEN gap_days END) AS median_gap,
    MAX(CASE WHEN rn = CEIL(0.75 * total) THEN gap_days END) AS p75_gap,
    MAX(CASE WHEN rn = CEIL(0.90 * total) THEN gap_days END) AS p90_gap,
    MAX(CASE WHEN rn = CEIL(0.95 * total) THEN gap_days END) AS p95_gap
FROM (
    SELECT
        gap_days,
        ROW_NUMBER() OVER (ORDER BY gap_days) AS rn,
        COUNT(*) OVER () AS total
    FROM order_gaps
) AS ranked;

-- Share of gaps above each candidate threshold
SELECT
    COUNT(*)                              AS total_gaps,
    ROUND(100 * AVG(gap_days > 60), 2)    AS pct_over_60,
    ROUND(100 * AVG(gap_days > 90), 2)    AS pct_over_90,
    ROUND(100 * AVG(gap_days > 120), 2)   AS pct_over_120,
    ROUND(100 * AVG(gap_days > 180), 2)   AS pct_over_180
FROM order_gaps;


-- one time buyers
-- Customers with only one invoice
SELECT COUNT(*) AS one_invoice_customers
FROM customer_summary
WHERE num_orders = 1;

-- Customers with no gaps at all (one order day, even if several invoices)
SELECT
    (SELECT COUNT(*) FROM customer_summary) -
    (SELECT COUNT(DISTINCT customer_id) FROM order_gaps) AS customers_without_gaps;


-- sanity checks 
-- Smallest gap must be at least 1
SELECT MIN(gap_days) AS min_gap, MAX(gap_days) AS max_gap FROM order_gaps;
-- Gaps must be fewer than order days
SELECT COUNT(*) AS gaps FROM order_gaps;
SELECT COUNT(*) AS order_days
FROM (SELECT DISTINCT customer_id, DATE(invoice_date) FROM orders) AS d;

CREATE OR REPLACE VIEW customer_churn AS 
SELECT 
    * , IF(days_since_last_purchase > 180  , 1,0) AS CHURNED FROM customer_summary c ;
