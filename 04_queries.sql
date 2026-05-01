USE fraud_detection_db;

-- ============================================================
-- SECTION C: CRUD OPERATIONS
-- ============================================================

-- SELECT: Get all active accounts with customer info
SELECT c.first_name, c.last_name, a.account_number, a.account_type, a.balance, a.status
FROM Customers c JOIN Accounts a ON c.customer_id = a.customer_id
WHERE a.status = 'Active' ORDER BY a.balance DESC;

-- SELECT: Recent fraud alerts with transaction details
SELECT fa.alert_id, fa.alert_type, fa.severity, t.amount, t.channel, t.location, fa.status
FROM FraudAlerts fa JOIN Transactions t ON fa.transaction_id = t.transaction_id
WHERE fa.status IN ('Open','Under_Review') ORDER BY fa.severity DESC, fa.created_at DESC;

-- INSERT: Add a new customer
INSERT INTO Customers (national_id, first_name, last_name, email, phone, city, risk_score)
VALUES ('30001011234567','New','Customer','new.customer@email.com','01155551234','Cairo',0);

-- UPDATE: Resolve a fraud alert
UPDATE FraudAlerts SET status = 'Resolved', resolved_at = NOW(), resolved_by = 3
WHERE alert_id = 3;

-- DELETE: Remove old resolved audit logs older than 1 year
DELETE FROM AuditLog WHERE created_at < DATE_SUB(NOW(), INTERVAL 1 YEAR) AND action = 'QUERY';

-- ============================================================
-- SECTION D: JOIN OPERATIONS
-- ============================================================

-- JOIN 1: Full fraud investigation view (multi-table)
SELECT c.first_name, c.last_name, c.risk_score,
       a.account_number, a.account_type, a.status AS acct_status,
       t.transaction_id, t.amount, t.channel, t.location, t.created_at AS txn_time,
       fa.alert_type, fa.severity, fa.status AS alert_status
FROM Customers c
INNER JOIN Accounts a ON c.customer_id = a.customer_id
INNER JOIN Transactions t ON a.account_id = t.account_id
INNER JOIN FraudAlerts fa ON t.transaction_id = fa.transaction_id
ORDER BY fa.severity DESC, t.amount DESC;

-- JOIN 2: All accounts with their flagged status (LEFT JOIN)
SELECT a.account_number, a.account_type, a.balance, a.status,
       fl.reason, fl.risk_level, fl.review_status
FROM Accounts a
LEFT JOIN FlaggedAccounts fl ON a.account_id = fl.account_id
ORDER BY fl.risk_level DESC;

-- JOIN 3: Fraud reports with investigator and alert details
SELECT fr.report_id, u.full_name AS investigator, fa.alert_type, fa.severity,
       t.amount, fr.findings, fr.recommendation, fr.status
FROM FraudReports fr
JOIN FraudAlerts fa ON fr.alert_id = fa.alert_id
JOIN Transactions t ON fa.transaction_id = t.transaction_id
JOIN Users u ON fr.investigator_id = u.user_id
ORDER BY fr.created_at DESC;

-- ============================================================
-- SECTION E: AGGREGATE FUNCTIONS
-- ============================================================

-- COUNT: Transactions per account
SELECT a.account_number, COUNT(t.transaction_id) AS total_transactions,
       SUM(t.amount) AS total_volume
FROM Accounts a JOIN Transactions t ON a.account_id = t.account_id
GROUP BY a.account_number ORDER BY total_transactions DESC;

-- SUM: Total fraud amounts by alert type
SELECT fa.alert_type, COUNT(*) AS alert_count,
       SUM(t.amount) AS total_flagged_amount, AVG(t.amount) AS avg_flagged_amount
FROM FraudAlerts fa JOIN Transactions t ON fa.transaction_id = t.transaction_id
GROUP BY fa.alert_type ORDER BY total_flagged_amount DESC;

-- AVG: Average transaction by channel
SELECT channel, COUNT(*) AS txn_count, AVG(amount) AS avg_amount,
       MIN(amount) AS min_amount, MAX(amount) AS max_amount
FROM Transactions GROUP BY channel ORDER BY avg_amount DESC;

-- Fraud rate by branch
SELECT b.branch_name, b.city, COUNT(DISTINCT t.transaction_id) AS total_txns,
       COUNT(DISTINCT fa.alert_id) AS fraud_alerts,
       ROUND(COUNT(DISTINCT fa.alert_id)*100.0/NULLIF(COUNT(DISTINCT t.transaction_id),0),2) AS fraud_rate_pct
FROM Branches b
JOIN Accounts a ON b.branch_id = a.branch_id
JOIN Transactions t ON a.account_id = t.account_id
LEFT JOIN FraudAlerts fa ON t.transaction_id = fa.transaction_id
GROUP BY b.branch_id ORDER BY fraud_rate_pct DESC;

-- ============================================================
-- SECTION F: SUBQUERIES
-- ============================================================

-- Accounts with transactions exceeding 3x their average
SELECT a.account_number, t.amount, t.created_at, t.channel
FROM Transactions t
JOIN Accounts a ON t.account_id = a.account_id
WHERE t.amount > 3 * (
    SELECT AVG(t2.amount) FROM Transactions t2 WHERE t2.account_id = t.account_id
)
ORDER BY t.amount DESC;

-- Customers with more than 2 fraud alerts
SELECT c.customer_id, c.first_name, c.last_name, c.risk_score, alert_counts.total_alerts
FROM Customers c
JOIN (
    SELECT a.customer_id, COUNT(fa.alert_id) AS total_alerts
    FROM Accounts a
    JOIN Transactions t ON a.account_id = t.account_id
    JOIN FraudAlerts fa ON t.transaction_id = fa.transaction_id
    GROUP BY a.customer_id HAVING COUNT(fa.alert_id) > 2
) alert_counts ON c.customer_id = alert_counts.customer_id
ORDER BY alert_counts.total_alerts DESC;

-- Top 5 highest risk customers not yet flagged
SELECT c.customer_id, c.first_name, c.last_name, c.risk_score
FROM Customers c WHERE c.risk_score > 30
AND c.customer_id NOT IN (
    SELECT DISTINCT a.customer_id FROM Accounts a
    JOIN FlaggedAccounts fl ON a.account_id = fl.account_id
    WHERE fl.review_status = 'Confirmed'
) ORDER BY c.risk_score DESC LIMIT 5;
