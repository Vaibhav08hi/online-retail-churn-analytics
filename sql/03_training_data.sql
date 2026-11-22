
-- Time-based training dataset for the churn prediction model
-- Cutoff date: 2011-08-12 (reference date 2011-12-10 minus 120 days)
-- Features use orders BEFORE the cutoff only
-- Label: churned_next_120d = 1 if no order from the cutoff onward
-- Eligible customers: at least one order before the cutoff

--  Eligible vs excluded customers

SELECT COUNT(DISTINCT customer_id) AS eligible_customers
FROM orders
WHERE invoice_date < '2011-08-12';

SELECT COUNT(*) AS excluded_new_customers
FROM customer_summary
WHERE first_purchase_date >= '2011-08-12';
-- eligible + excluded should equal 5852


-- Features + label in one view

CREATE OR REPLACE VIEW churn_training_data AS
SELECT
    f.customer_id,
    f.recency_days,
    f.frequency,
    f.total_spend,
    f.avg_order_value,
    f.tenure_days,
    f.distinct_products,
    f.orders_last_90d,
    COALESCE(r.return_count, 0)              AS return_count,
    c.country,
    IF(l.customer_id IS NULL, 1, 0)          AS churned_next_120d
FROM (
    -- Features: only orders before the cutoff
    SELECT
        o.customer_id,
        DATEDIFF('2011-08-12', DATE(MAX(o.invoice_date)))                  AS recency_days,
        COUNT(DISTINCT o.invoice_no)                                       AS frequency,
        ROUND(SUM(oi.revenue), 2)                                          AS total_spend,
        ROUND(SUM(oi.revenue) / COUNT(DISTINCT o.invoice_no), 2)           AS avg_order_value,
        DATEDIFF('2011-08-12', DATE(MIN(o.invoice_date)))                  AS tenure_days,
        COUNT(DISTINCT oi.stock_code)                                      AS distinct_products,
        COUNT(DISTINCT CASE
                WHEN o.invoice_date >= '2011-08-12' - INTERVAL 90 DAY
                THEN o.invoice_no END)                                     AS orders_last_90d
    FROM orders o
    JOIN order_items oi ON oi.invoice_no = o.invoice_no
    WHERE o.invoice_date < '2011-08-12'
    GROUP BY o.customer_id
) f
JOIN customers c ON c.customer_id = f.customer_id
LEFT JOIN (
    -- Returns before the cutoff
    SELECT customer_id, COUNT(DISTINCT invoice_no) AS return_count
    FROM returns
    WHERE invoice_date < '2011-08-12'
    GROUP BY customer_id
) r ON r.customer_id = f.customer_id
LEFT JOIN (
    -- Customers who ordered in the label period
    SELECT DISTINCT customer_id
    FROM orders
    WHERE invoice_date >= '2011-08-12' AND invoice_date < '2011-12-10'
) l ON l.customer_id = f.customer_id;


-- 6.6 Checks


-- 1. Row count (must equal eligible_customers above)
SELECT COUNT(*) AS rows_in_view FROM churn_training_data;

-- 2. Leakage test: recency must be at least 1 (a post-cutoff order would make it 0 or negative)
SELECT MIN(recency_days) AS min_recency FROM churn_training_data;

-- Latest order that any feature could use (should be 2011-08-11)
SELECT MAX(DATE(invoice_date)) AS latest_feature_date
FROM orders
WHERE invoice_date < '2011-08-12';

-- 3. No customers whose first order is on or after the cutoff (expect 0)
SELECT COUNT(*) AS new_customers_in_view
FROM churn_training_data t
JOIN customer_summary s ON s.customer_id = t.customer_id
WHERE s.first_purchase_date >= '2011-08-12';

-- 4. Impossible values (expect all 0)
SELECT
    SUM(frequency < 1)         AS bad_frequency,
    SUM(total_spend <= 0)      AS bad_spend,
    SUM(tenure_days < 0)       AS bad_tenure,
    SUM(recency_days < 1)      AS bad_recency
FROM churn_training_data;

-- 5. Label rate
SELECT
    COUNT(*)                                AS customers,
    SUM(churned_next_120d)                  AS churned,
    COUNT(*) - SUM(churned_next_120d)       AS retained,
    ROUND(100 * AVG(churned_next_120d), 2)  AS churn_rate_pct
FROM churn_training_data;

-- 6. Hand-check samples (look up these customers in the orders table)
SELECT * FROM churn_training_data WHERE churned_next_120d = 1 LIMIT 3;
SELECT * FROM churn_training_data WHERE churned_next_120d = 0 LIMIT 3;
SELECT * FROM churn_training_data WHERE frequency = 1 LIMIT 3;

-- 7. Customers already inactive at the cutoff (will almost all be labeled 1)
SELECT
    COUNT(*)                                AS inactive_at_cutoff,
    ROUND(100 * AVG(churned_next_120d), 2)  AS churn_rate_pct
FROM churn_training_data
WHERE recency_days >= 120;

-- 8. Does the signal look sensible? Churn rate by recency bucket
SELECT
    CASE WHEN recency_days < 30  THEN '1: under 30 days'
         WHEN recency_days < 90  THEN '2: 30-89 days'
         WHEN recency_days < 180 THEN '3: 90-179 days'
         ELSE '4: 180+ days' END            AS recency_bucket,
    COUNT(*)                                AS customers,
    ROUND(100 * AVG(churned_next_120d), 2)  AS churn_rate_pct
FROM churn_training_data
GROUP BY recency_bucket
ORDER BY recency_bucket;