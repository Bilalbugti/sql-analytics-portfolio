-- ============================================================
-- KPI & REPORTING QUERIES
-- Business context: the exact style of query that powers a
-- Power BI / Tableau dashboard - pre-aggregated, business-readable
-- metrics ready to plug into a BI tool.
-- ============================================================

-- 1. Branch performance scorecard (core KPI dashboard query)
SELECT
    b.branch_name,
    b.region,
    COUNT(DISTINCT c.customer_id)              AS total_customers,
    COUNT(DISTINCT a.account_id)                AS total_accounts,
    COUNT(t.transaction_id)                      AS total_transactions,
    ROUND(SUM(t.amount), 2)                      AS total_transaction_value,
    ROUND(AVG(t.amount), 2)                      AS avg_transaction_value
FROM branches b
LEFT JOIN customers c ON c.branch_id = b.branch_id
LEFT JOIN accounts a ON a.customer_id = c.customer_id
LEFT JOIN transactions t ON t.account_id = a.account_id
GROUP BY b.branch_id, b.branch_name, b.region
ORDER BY total_transaction_value DESC;


-- 2. KYC compliance status breakdown (matches real KYC monitoring dashboards)
SELECT
    kyc_status,
    COUNT(*) AS customer_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM customers), 2) AS pct_of_total
FROM customers
GROUP BY kyc_status
ORDER BY customer_count DESC;


-- 3. KYC records overdue for renewal (SLA-style monitoring)
--    Rule: KYC should be refreshed within 365 days
SELECT
    customer_id,
    full_name,
    kyc_status,
    kyc_last_updated,
    CAST(julianday('now') - julianday(kyc_last_updated) AS INTEGER) AS days_since_update
FROM customers
WHERE kyc_status = 'VERIFIED'
  AND julianday('now') - julianday(kyc_last_updated) > 365
ORDER BY days_since_update DESC;


-- 4. Transaction channel mix (for a "digital adoption" KPI panel)
SELECT
    channel,
    COUNT(*) AS transaction_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM transactions), 2) AS pct_of_all_transactions,
    ROUND(SUM(amount), 2) AS total_value
FROM transactions
GROUP BY channel
ORDER BY transaction_count DESC;


-- 5. New customer acquisition trend by month (growth KPI)
SELECT
    strftime('%Y-%m', signup_date) AS signup_month,
    COUNT(*) AS new_customers
FROM customers
GROUP BY signup_month
ORDER BY signup_month;


-- 6. Account type distribution per region (mix analysis)
SELECT
    b.region,
    a.account_type,
    COUNT(*) AS account_count
FROM accounts a
JOIN customers c ON a.customer_id = c.customer_id
JOIN branches b ON c.branch_id = b.branch_id
GROUP BY b.region, a.account_type
ORDER BY b.region, account_count DESC;
