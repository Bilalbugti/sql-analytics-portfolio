-- ============================================================
-- WINDOW FUNCTIONS
-- Business context: ranking, running totals, and period-over-period
-- comparisons - the kind of queries used for KPI dashboards and
-- customer analytics in retail banking.
-- ============================================================

-- 1. Rank customers within each branch by total transaction value
--    (business use: identify top customers per branch for relationship management)
SELECT
    c.customer_id,
    c.full_name,
    b.branch_name,
    ROUND(SUM(t.amount), 2) AS total_transaction_value,
    RANK() OVER (PARTITION BY b.branch_id ORDER BY SUM(t.amount) DESC) AS branch_rank
FROM customers c
JOIN branches b ON c.branch_id = b.branch_id
JOIN accounts a ON a.customer_id = c.customer_id
JOIN transactions t ON t.account_id = a.account_id
GROUP BY c.customer_id, c.full_name, b.branch_id, b.branch_name
ORDER BY b.branch_name, branch_rank
LIMIT 50;


-- 2. Running (cumulative) monthly transaction total per branch
--    (business use: trend monitoring for a branch performance dashboard)
WITH monthly_totals AS (
    SELECT
        b.branch_name,
        strftime('%Y-%m', t.transaction_date) AS month,
        SUM(t.amount) AS monthly_amount
    FROM transactions t
    JOIN accounts a ON t.account_id = a.account_id
    JOIN customers c ON a.customer_id = c.customer_id
    JOIN branches b ON c.branch_id = b.branch_id
    GROUP BY b.branch_name, month
)
SELECT
    branch_name,
    month,
    monthly_amount,
    ROUND(
        SUM(monthly_amount) OVER (PARTITION BY branch_name ORDER BY month),
        2
    ) AS running_total
FROM monthly_totals
ORDER BY branch_name, month;


-- 3. Month-over-month transaction volume growth (LAG)
--    (business use: same KPI pattern used for MoM growth reporting)
WITH monthly_volume AS (
    SELECT
        strftime('%Y-%m', transaction_date) AS month,
        COUNT(*) AS txn_count
    FROM transactions
    GROUP BY month
)
SELECT
    month,
    txn_count,
    LAG(txn_count) OVER (ORDER BY month) AS prev_month_count,
    ROUND(
        100.0 * (txn_count - LAG(txn_count) OVER (ORDER BY month))
        / NULLIF(LAG(txn_count) OVER (ORDER BY month), 0),
        2
    ) AS mom_growth_pct
FROM monthly_volume
ORDER BY month;


-- 4. Each customer's most recent transaction (ROW_NUMBER, "latest record per group")
--    (business use: a very common real-world pattern - dedupe to latest activity)
WITH ranked_txns AS (
    SELECT
        a.customer_id,
        t.transaction_id,
        t.transaction_date,
        t.amount,
        ROW_NUMBER() OVER (
            PARTITION BY a.customer_id ORDER BY t.transaction_date DESC
        ) AS rn
    FROM transactions t
    JOIN accounts a ON t.account_id = a.account_id
)
SELECT customer_id, transaction_id, transaction_date, amount
FROM ranked_txns
WHERE rn = 1
ORDER BY transaction_date DESC
LIMIT 20;
