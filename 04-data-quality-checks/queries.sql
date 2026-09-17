-- ============================================================
-- DATA QUALITY & VALIDATION QUERIES
-- Business context: the SQL-side checks that would run before
-- trusting a dataset for reporting - matches the automated
-- validation layer described in the Transaction ETL Pipeline project.
-- ============================================================

-- 1. Orphaned accounts (accounts referencing a customer_id that doesn't exist)
--    (business use: referential integrity check - catches upstream sync bugs)
SELECT a.account_id, a.customer_id
FROM accounts a
LEFT JOIN customers c ON a.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- 2. Duplicate customers by name (potential duplicate records - fuzzy business check)
--    Note: name-matching alone isn't proof of duplication in production,
--    this flags candidates for manual/deeper review.
SELECT
    full_name,
    COUNT(*) AS record_count
FROM customers
GROUP BY full_name
HAVING COUNT(*) > 1
ORDER BY record_count DESC;


-- 3. Transactions with implausible values (business rule validation)
--    Rule: no single transaction should exceed 250,000 in absolute value
--    given this portfolio's typical customer base
SELECT
    transaction_id,
    account_id,
    transaction_type,
    amount,
    transaction_date
FROM transactions
WHERE ABS(amount) > 250000
ORDER BY ABS(amount) DESC;


-- 4. Accounts opened before their customer signed up (logical inconsistency check)
--    (business use: catches data entry errors / sequencing bugs upstream)
SELECT
    a.account_id,
    a.customer_id,
    a.opened_date,
    c.signup_date
FROM accounts a
JOIN customers c ON a.customer_id = c.customer_id
WHERE a.opened_date < c.signup_date;


-- 5. Overall data quality summary (single "health check" panel)
SELECT
    'orphaned_accounts' AS check_name,
    COUNT(*) AS issue_count
FROM accounts a
LEFT JOIN customers c ON a.customer_id = c.customer_id
WHERE c.customer_id IS NULL

UNION ALL

SELECT
    'implausible_transaction_amounts',
    COUNT(*)
FROM transactions
WHERE ABS(amount) > 250000

UNION ALL

SELECT
    'accounts_opened_before_signup',
    COUNT(*)
FROM accounts a
JOIN customers c ON a.customer_id = c.customer_id
WHERE a.opened_date < c.signup_date;
