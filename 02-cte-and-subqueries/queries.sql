-- ============================================================
-- CTEs AND SUBQUERIES
-- Business context: multi-step analytical logic broken into
-- readable stages - the pattern used for segmentation and
-- behavioral analysis.
-- ============================================================

-- 1. Customer segmentation by transaction activity (CTE + CASE)
--    (business use: classify customers into activity tiers for
--     targeted engagement - a common ask from business stakeholders)
WITH customer_activity AS (
    SELECT
        c.customer_id,
        c.full_name,
        COUNT(t.transaction_id) AS txn_count,
        ROUND(SUM(t.amount), 2) AS total_value
    FROM customers c
    JOIN accounts a ON a.customer_id = c.customer_id
    JOIN transactions t ON t.account_id = a.account_id
    GROUP BY c.customer_id, c.full_name
)
SELECT
    customer_id,
    full_name,
    txn_count,
    total_value,
    CASE
        WHEN txn_count >= 40 THEN 'HIGH_ACTIVITY'
        WHEN txn_count >= 15 THEN 'MEDIUM_ACTIVITY'
        ELSE 'LOW_ACTIVITY'
    END AS activity_tier
FROM customer_activity
ORDER BY txn_count DESC
LIMIT 50;


-- 2. Customers with above-average transaction value (correlated subquery)
--    (business use: flag high-value customers relative to their branch peers)
SELECT
    c.customer_id,
    c.full_name,
    b.branch_name,
    ROUND(SUM(t.amount), 2) AS total_value
FROM customers c
JOIN branches b ON c.branch_id = b.branch_id
JOIN accounts a ON a.customer_id = c.customer_id
JOIN transactions t ON t.account_id = a.account_id
GROUP BY c.customer_id, c.full_name, b.branch_name
HAVING SUM(t.amount) > (
    SELECT AVG(branch_avg.branch_total)
    FROM (
        SELECT SUM(t2.amount) AS branch_total
        FROM customers c2
        JOIN accounts a2 ON a2.customer_id = c2.customer_id
        JOIN transactions t2 ON t2.account_id = a2.account_id
        WHERE c2.branch_id = c.branch_id
        GROUP BY c2.customer_id
    ) branch_avg
)
ORDER BY total_value DESC
LIMIT 30;


-- 3. Accounts with no transactions in the last 90 days (dormant account detection)
--    (business use: operational risk / dormancy monitoring - a real
--     banking compliance requirement)
WITH last_activity AS (
    SELECT
        a.account_id,
        a.customer_id,
        a.account_type,
        MAX(t.transaction_date) AS last_txn_date
    FROM accounts a
    LEFT JOIN transactions t ON t.account_id = a.account_id
    WHERE a.status = 'ACTIVE'
    GROUP BY a.account_id, a.customer_id, a.account_type
)
SELECT
    account_id,
    customer_id,
    account_type,
    last_txn_date,
    CASE
        WHEN last_txn_date IS NULL THEN 'NEVER_USED'
        ELSE CAST(julianday('now') - julianday(last_txn_date) AS INTEGER) || ' days ago'
    END AS days_since_last_activity
FROM last_activity
WHERE last_txn_date IS NULL
   OR julianday('now') - julianday(last_txn_date) > 90
ORDER BY last_txn_date;


-- 4. Multi-account customers and their combined portfolio (nested CTE)
--    (business use: relationship-level view instead of account-level,
--     common ask for a "customer 360" style report)
WITH account_summary AS (
    SELECT
        customer_id,
        COUNT(*) AS num_accounts,
        GROUP_CONCAT(account_type) AS account_types
    FROM accounts
    WHERE status = 'ACTIVE'
    GROUP BY customer_id
),
multi_account_customers AS (
    SELECT * FROM account_summary WHERE num_accounts > 1
)
SELECT
    m.customer_id,
    c.full_name,
    m.num_accounts,
    m.account_types
FROM multi_account_customers m
JOIN customers c ON c.customer_id = m.customer_id
ORDER BY m.num_accounts DESC
LIMIT 30;
