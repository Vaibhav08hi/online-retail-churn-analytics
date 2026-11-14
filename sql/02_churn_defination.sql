-- latest date - '2011-12-09'
--earliest invoice_date - '2009-12-01'
--Reference date: day after the last invoice in the data - '2011-12-10'

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