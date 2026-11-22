-- Churn definition for the Online Retail II project
-- Reference date: 2011-12-10 (day after the last invoice, 2011-12-09)
-- Churn rule: a customer is churned if days since last purchase >= 120
-- Purchases are counted from the orders table only (returns are ignored)


-- Customer summary (one row per customer)

CREATE OR REPLACE VIEW customer_summary AS
SELECT
    o.customer_id,
    DATE(MIN(o.invoice_date))                                       AS first_purchase_date,
    DATE(MAX(o.invoice_date))                                       AS last_purchase_date,
    COUNT(DISTINCT o.invoice_no)                                    AS num_orders,
    ROUND(SUM(oi.revenue), 2)                                       AS total_spend,
    ROUND(SUM(oi.revenue) / COUNT(DISTINCT o.invoice_no), 2)        AS avg_order_value,
    DATEDIFF(r.ref_date, DATE(MAX(o.invoice_date)))                 AS days_since_last_purchase,
    DATEDIFF(DATE(MAX(o.invoice_date)), DATE(MIN(o.invoice_date)))  AS customer_lifetime_days
FROM orders o
JOIN order_items oi ON oi.invoice_no = o.invoice_no
CROSS JOIN (
    SELECT DATE(MAX(invoice_date)) + INTERVAL 1 DAY AS ref_date
    FROM orders
) r
GROUP BY o.customer_id, r.ref_date;

-- Checks (expect 5852 rows, spend 17068567.97, min days >= 1, last result 0)
SELECT COUNT(*) AS customers_in_view FROM customer_summary;
SELECT SUM(total_spend) AS view_total FROM customer_summary;
SELECT SUM(revenue) AS table_total FROM order_items;
SELECT MIN(days_since_last_purchase) AS min_days FROM customer_summary;
SELECT COUNT(*) AS bad_one_order_rows
FROM customer_summary
WHERE num_orders = 1 AND customer_lifetime_days <> 0;


-- STEP 3: Gaps between orders (evidence for the threshold)

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

-- Percentiles of the gaps (expect 27026 gaps, median 32, p75 70, p90 148, p95 221)
SELECT
    MAX(total)                                                AS total_gaps,
    MAX(CASE WHEN rn = CEIL(0.50 * total) THEN gap_days END)  AS median_gap,
    MAX(CASE WHEN rn = CEIL(0.75 * total) THEN gap_days END)  AS p75_gap,
    MAX(CASE WHEN rn = CEIL(0.90 * total) THEN gap_days END)  AS p90_gap,
    MAX(CASE WHEN rn = CEIL(0.95 * total) THEN gap_days END)  AS p95_gap
FROM (
    SELECT
        gap_days,
        ROW_NUMBER() OVER (ORDER BY gap_days) AS rn,
        COUNT(*) OVER () AS total
    FROM order_gaps
) AS ranked;

-- Share of normal gaps longer than each candidate threshold
SELECT
    COUNT(*)                            AS total_gaps,
    ROUND(100 * AVG(gap_days > 60), 2)  AS pct_over_60,
    ROUND(100 * AVG(gap_days > 90), 2)  AS pct_over_90,
    ROUND(100 * AVG(gap_days > 120), 2) AS pct_over_120,
    ROUND(100 * AVG(gap_days > 180), 2) AS pct_over_180
FROM order_gaps;

-- Customers with no gaps
SELECT COUNT(*) AS one_invoice_customers
FROM customer_summary
WHERE num_orders = 1;

SELECT
    (SELECT COUNT(*) FROM customer_summary) -
    (SELECT COUNT(DISTINCT customer_id) FROM order_gaps) AS customers_without_gaps;

-- Sanity checks (min gap must be at least 1, gaps must be fewer than order days)
SELECT MIN(gap_days) AS min_gap, MAX(gap_days) AS max_gap FROM order_gaps;
SELECT COUNT(*) AS gaps FROM order_gaps;
SELECT COUNT(*) AS order_days
FROM (SELECT DISTINCT customer_id, DATE(invoice_date) FROM orders) AS d;


-- STEP 4: Churn flag (threshold lives in one place: churn_days)

CREATE OR REPLACE VIEW customer_churn AS
SELECT
    cs.*,
    IF(cs.days_since_last_purchase >= p.churn_days, 1, 0) AS is_churned
FROM customer_summary cs
CROSS JOIN (SELECT 120 AS churn_days) p;

-- Overall churn rate
SELECT
    COUNT(*)                         AS customers,
    SUM(is_churned)                  AS churned,
    COUNT(*) - SUM(is_churned)       AS active,
    ROUND(100 * AVG(is_churned), 2)  AS churn_rate_pct
FROM customer_churn;

-- Sanity checks (churned min >= 120, active max < 120)
SELECT MIN(days_since_last_purchase) AS min_days_churned
FROM customer_churn WHERE is_churned = 1;
SELECT MAX(days_since_last_purchase) AS max_days_active
FROM customer_churn WHERE is_churned = 0;

-- Churn by number of orders
SELECT
    CASE WHEN num_orders = 1 THEN '1 order'
         WHEN num_orders BETWEEN 2 AND 3 THEN '2-3 orders'
         ELSE '4+ orders' END         AS order_group,
    COUNT(*)                          AS customers,
    SUM(is_churned)                   AS churned,
    ROUND(100 * AVG(is_churned), 2)   AS churn_rate_pct
FROM customer_churn
GROUP BY order_group
ORDER BY MIN(num_orders);

-- Churn by spend quartile (1 = lowest spenders, 4 = highest)
SELECT
    spend_quartile,
    COUNT(*)                          AS customers,
    SUM(is_churned)                   AS churned,
    ROUND(100 * AVG(is_churned), 2)   AS churn_rate_pct,
    MIN(total_spend)                  AS min_spend,
    MAX(total_spend)                  AS max_spend
FROM (
    SELECT *, NTILE(4) OVER (ORDER BY total_spend) AS spend_quartile
    FROM customer_churn
) q
GROUP BY spend_quartile
ORDER BY spend_quartile;

-- Churn by country (top 5 by customer count)
SELECT
    c.country,
    COUNT(*)                          AS customers,
    SUM(cc.is_churned)                AS churned,
    ROUND(100 * AVG(cc.is_churned), 2) AS churn_rate_pct
FROM customer_churn cc
JOIN customers c ON c.customer_id = cc.customer_id
GROUP BY c.country
ORDER BY customers DESC
LIMIT 5;

-- Churn by year of first purchase
SELECT
    YEAR(first_purchase_date)         AS first_purchase_year,
    COUNT(*)                          AS customers,
    SUM(is_churned)                   AS churned,
    ROUND(100 * AVG(is_churned), 2)   AS churn_rate_pct
FROM customer_churn
GROUP BY first_purchase_year
ORDER BY first_purchase_year;


-- STEP 5: Sensitivity analysis (churn rate at different thresholds)
-- Churn rate must fall as the threshold rises

SELECT
    t.threshold_days,
    SUM(cs.days_since_last_purchase >= t.threshold_days)                   AS churned,
    COUNT(*) - SUM(cs.days_since_last_purchase >= t.threshold_days)        AS active,
    ROUND(100 * AVG(cs.days_since_last_purchase >= t.threshold_days), 2)   AS churn_rate_pct
FROM customer_summary cs
CROSS JOIN (
    SELECT 60 AS threshold_days
    UNION ALL SELECT 90
    UNION ALL SELECT 120
    UNION ALL SELECT 180
) t
GROUP BY t.threshold_days
ORDER BY t.threshold_days;

