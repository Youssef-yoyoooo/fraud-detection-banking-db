USE fraud_detection_db;

-- ============================================================
-- SECTION G: STORED PROCEDURES
-- ============================================================

DELIMITER //

-- SP1: Detect high-value fraud transactions
CREATE PROCEDURE sp_detect_high_value_fraud(IN p_threshold DECIMAL(15,2))
BEGIN
    DECLARE v_txn_id INT;
    DECLARE v_amount DECIMAL(15,2);
    DECLARE v_done INT DEFAULT 0;
    DECLARE cur CURSOR FOR
        SELECT t.transaction_id, t.amount FROM Transactions t
        LEFT JOIN FraudAlerts fa ON t.transaction_id = fa.transaction_id AND fa.alert_type = 'High_Value'
        WHERE t.amount >= p_threshold AND fa.alert_id IS NULL;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    OPEN cur;
    read_loop: LOOP
        FETCH cur INTO v_txn_id, v_amount;
        IF v_done THEN LEAVE read_loop; END IF;
        INSERT INTO FraudAlerts (transaction_id, rule_id, alert_type, severity, description, status)
        VALUES (v_txn_id, 1, 'High_Value',
            CASE WHEN v_amount >= 50000 THEN 'Critical'
                 WHEN v_amount >= 20000 THEN 'High'
                 WHEN v_amount >= 10000 THEN 'Medium'
                 ELSE 'Low' END,
            CONCAT('Auto-detected: Transaction amount $', FORMAT(v_amount,2), ' exceeds threshold $', FORMAT(p_threshold,2)),
            'Open');
    END LOOP;
    CLOSE cur;
    SELECT CONCAT('High-value fraud scan completed with threshold $', FORMAT(p_threshold,2)) AS result;
END //

-- SP2: Detect velocity fraud (rapid-fire transactions)
CREATE PROCEDURE sp_detect_velocity_fraud(IN p_account_id INT, IN p_time_window INT, IN p_max_count INT)
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count FROM Transactions
    WHERE account_id = p_account_id
    AND created_at >= DATE_SUB(NOW(), INTERVAL p_time_window MINUTE);

    IF v_count > p_max_count THEN
        INSERT INTO FraudAlerts (transaction_id, rule_id, alert_type, severity, description, status)
        SELECT transaction_id, 2, 'Velocity', 'High',
            CONCAT('Velocity fraud: ', v_count, ' transactions in ', p_time_window, ' minutes (max: ', p_max_count, ')'),
            'Open'
        FROM Transactions WHERE account_id = p_account_id
        ORDER BY created_at DESC LIMIT 1;
        SELECT CONCAT('ALERT: ', v_count, ' transactions detected for account ', p_account_id) AS result;
    ELSE
        SELECT CONCAT('OK: ', v_count, ' transactions for account ', p_account_id, ' within limits') AS result;
    END IF;
END //

-- SP3: Generate fraud report
CREATE PROCEDURE sp_generate_fraud_report(
    IN p_alert_id INT, IN p_investigator_id INT,
    IN p_findings TEXT, IN p_recommendation VARCHAR(50))
BEGIN
    DECLARE v_exists INT;
    SELECT COUNT(*) INTO v_exists FROM FraudAlerts WHERE alert_id = p_alert_id;
    IF v_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Alert ID does not exist';
    END IF;

    INSERT INTO FraudReports (alert_id, investigator_id, findings, recommendation, status)
    VALUES (p_alert_id, p_investigator_id, p_findings, p_recommendation, 'Submitted');

    UPDATE FraudAlerts SET status = 'Under_Review' WHERE alert_id = p_alert_id AND status = 'Open';
    SELECT LAST_INSERT_ID() AS new_report_id, 'Report created successfully' AS result;
END //

-- SP4: Update customer risk score based on fraud history
CREATE PROCEDURE sp_update_risk_score(IN p_customer_id INT)
BEGIN
    DECLARE v_score INT DEFAULT 0;
    DECLARE v_confirmed INT; DECLARE v_open INT; DECLARE v_total_flagged DECIMAL(15,2);

    SELECT COUNT(*) INTO v_confirmed FROM FraudAlerts fa
    JOIN Transactions t ON fa.transaction_id = t.transaction_id
    JOIN Accounts a ON t.account_id = a.account_id
    WHERE a.customer_id = p_customer_id AND fa.status = 'Confirmed_Fraud';

    SELECT COUNT(*) INTO v_open FROM FraudAlerts fa
    JOIN Transactions t ON fa.transaction_id = t.transaction_id
    JOIN Accounts a ON t.account_id = a.account_id
    WHERE a.customer_id = p_customer_id AND fa.status IN ('Open','Under_Review');

    SELECT COALESCE(SUM(t.amount),0) INTO v_total_flagged FROM FraudAlerts fa
    JOIN Transactions t ON fa.transaction_id = t.transaction_id
    JOIN Accounts a ON t.account_id = a.account_id
    WHERE a.customer_id = p_customer_id AND fa.status != 'False_Positive';

    SET v_score = (v_confirmed * 25) + (v_open * 10) + LEAST(FLOOR(v_total_flagged / 10000), 25);
    SET v_score = LEAST(v_score, 100);
    UPDATE Customers SET risk_score = v_score WHERE customer_id = p_customer_id;
    SELECT p_customer_id AS customer_id, v_score AS new_risk_score,
           v_confirmed AS confirmed_frauds, v_open AS open_alerts, v_total_flagged AS total_flagged_amount;
END //

-- SP5: Safe fund transfer with fraud check
CREATE PROCEDURE sp_fund_transfer(IN p_from INT, IN p_to INT, IN p_amount DECIMAL(15,2))
BEGIN
    DECLARE v_balance DECIMAL(15,2);
    DECLARE v_from_status VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

    START TRANSACTION;
    SELECT balance, status INTO v_balance, v_from_status FROM Accounts WHERE account_id = p_from FOR UPDATE;
    IF v_from_status != 'Active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Source account is not active';
    END IF;
    IF v_balance < p_amount THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient balance';
    END IF;

    UPDATE Accounts SET balance = balance - p_amount WHERE account_id = p_from;
    UPDATE Accounts SET balance = balance + p_amount WHERE account_id = p_to;

    INSERT INTO Transactions (account_id, transaction_type, amount, counterparty_account, channel, description, status)
    VALUES (p_from, 'Transfer', p_amount, (SELECT account_number FROM Accounts WHERE account_id = p_to),
            'Online', CONCAT('Transfer to account ', p_to), 'Completed');

    IF p_amount >= 10000 THEN
        INSERT INTO FraudAlerts (transaction_id, rule_id, alert_type, severity, description, status)
        VALUES (LAST_INSERT_ID(), 1, 'High_Value',
            CASE WHEN p_amount >= 50000 THEN 'Critical' WHEN p_amount >= 20000 THEN 'High' ELSE 'Medium' END,
            CONCAT('Auto-flagged transfer: $', FORMAT(p_amount,2)), 'Open');
    END IF;
    COMMIT;
    SELECT 'Transfer completed successfully' AS result, p_amount AS amount_transferred;
END //

DELIMITER ;

-- ============================================================
-- SECTION H: TRIGGERS
-- ============================================================

DELIMITER //

-- Trigger 1: Auto-check new transactions against fraud rules
CREATE TRIGGER trg_after_transaction_insert
AFTER INSERT ON Transactions
FOR EACH ROW
BEGIN
    -- Check high-value rule
    IF NEW.amount >= 10000 THEN
        INSERT INTO AuditLog (user_id, action, table_affected, record_id, new_value)
        VALUES (NULL, 'INSERT', 'Transactions', NEW.transaction_id,
            CONCAT('High-value transaction: $', FORMAT(NEW.amount,2), ' via ', NEW.channel));
    END IF;
    -- Check midnight rule
    IF HOUR(NEW.created_at) BETWEEN 1 AND 4 AND NEW.amount >= 5000 THEN
        INSERT INTO AuditLog (user_id, action, table_affected, record_id, new_value)
        VALUES (NULL, 'INSERT', 'Transactions', NEW.transaction_id,
            CONCAT('Midnight transaction alert: $', FORMAT(NEW.amount,2), ' at ', TIME(NEW.created_at)));
    END IF;
END //

-- Trigger 2: Update account risk when alert is resolved
CREATE TRIGGER trg_after_alert_update
AFTER UPDATE ON FraudAlerts
FOR EACH ROW
BEGIN
    IF OLD.status != NEW.status AND NEW.status IN ('Confirmed_Fraud','Resolved','False_Positive') THEN
        INSERT INTO AuditLog (user_id, action, table_affected, record_id, old_value, new_value)
        VALUES (NEW.resolved_by, 'UPDATE', 'FraudAlerts', NEW.alert_id,
            CONCAT('status=', OLD.status), CONCAT('status=', NEW.status));
    END IF;
END //

-- Trigger 3: Log account status changes
CREATE TRIGGER trg_account_status_change
AFTER UPDATE ON Accounts
FOR EACH ROW
BEGIN
    IF OLD.status != NEW.status THEN
        INSERT INTO AuditLog (user_id, action, table_affected, record_id, old_value, new_value)
        VALUES (NULL, 'UPDATE', 'Accounts', NEW.account_id,
            CONCAT('status=', OLD.status), CONCAT('status=', NEW.status));
    END IF;
END //

DELIMITER ;

-- ============================================================
-- SECTION I: TRANSACTIONS (ACID DEMONSTRATION)
-- ============================================================

-- Transaction 1: Fund transfer with rollback on insufficient balance
START TRANSACTION;
UPDATE Accounts SET balance = balance - 5000 WHERE account_id = 1;
UPDATE Accounts SET balance = balance + 5000 WHERE account_id = 2;
-- Verify
SELECT account_id, balance FROM Accounts WHERE account_id IN (1,2);
COMMIT;

-- Transaction 2: Batch fraud alert status update
START TRANSACTION;
UPDATE FraudAlerts SET status = 'Under_Review'
WHERE status = 'Open' AND severity = 'Critical' AND created_at < DATE_SUB(NOW(), INTERVAL 24 HOUR);
-- If too many alerts affected, rollback
-- ROLLBACK;
COMMIT;

-- Transaction 3: Freeze account with cascading updates
START TRANSACTION;
UPDATE Accounts SET status = 'Frozen' WHERE account_id = 7;
INSERT INTO FlaggedAccounts (account_id, reason, risk_level, review_status)
SELECT 7, 'Account frozen due to fraud investigation', 'Critical', 'Pending'
FROM DUAL WHERE NOT EXISTS (
    SELECT 1 FROM FlaggedAccounts WHERE account_id = 7 AND review_status IN ('Pending','Under_Review')
);
COMMIT;

-- ============================================================
-- SECTION K: VIEWS
-- ============================================================

-- View 1: Fraud Dashboard Summary
CREATE OR REPLACE VIEW vw_fraud_dashboard AS
SELECT
    (SELECT COUNT(*) FROM FraudAlerts WHERE status = 'Open') AS open_alerts,
    (SELECT COUNT(*) FROM FraudAlerts WHERE status = 'Under_Review') AS under_review,
    (SELECT COUNT(*) FROM FraudAlerts WHERE status = 'Confirmed_Fraud') AS confirmed_frauds,
    (SELECT COUNT(*) FROM FraudAlerts WHERE status = 'False_Positive') AS false_positives,
    (SELECT COUNT(*) FROM FlaggedAccounts WHERE review_status = 'Pending') AS pending_flags,
    (SELECT COALESCE(SUM(t.amount),0) FROM FraudAlerts fa JOIN Transactions t ON fa.transaction_id = t.transaction_id WHERE fa.status = 'Confirmed_Fraud') AS total_confirmed_fraud_amount,
    (SELECT COUNT(*) FROM Accounts WHERE status = 'Frozen') AS frozen_accounts;

-- View 2: Suspicious transactions
CREATE OR REPLACE VIEW vw_suspicious_transactions AS
SELECT t.transaction_id, c.first_name, c.last_name, a.account_number,
       t.amount, t.channel, t.location, t.ip_address, t.created_at,
       fa.alert_type, fa.severity, fa.status AS alert_status
FROM Transactions t
JOIN Accounts a ON t.account_id = a.account_id
JOIN Customers c ON a.customer_id = c.customer_id
JOIN FraudAlerts fa ON t.transaction_id = fa.transaction_id
WHERE fa.status IN ('Open','Under_Review')
ORDER BY fa.severity DESC;

-- View 3: Account risk profile
CREATE OR REPLACE VIEW vw_account_risk_profile AS
SELECT c.customer_id, c.first_name, c.last_name, c.risk_score,
       a.account_number, a.account_type, a.balance, a.status,
       COUNT(DISTINCT fa.alert_id) AS total_alerts,
       SUM(CASE WHEN fa.status = 'Confirmed_Fraud' THEN 1 ELSE 0 END) AS confirmed_frauds,
       COALESCE(MAX(fl.risk_level),'None') AS flag_level
FROM Customers c
JOIN Accounts a ON c.customer_id = a.customer_id
LEFT JOIN Transactions t ON a.account_id = t.account_id
LEFT JOIN FraudAlerts fa ON t.transaction_id = fa.transaction_id
LEFT JOIN FlaggedAccounts fl ON a.account_id = fl.account_id
GROUP BY c.customer_id, a.account_id
ORDER BY c.risk_score DESC;

-- ============================================================
-- SECTION J: QUERY OPTIMIZATION WITH EXPLAIN
-- ============================================================

-- EXPLAIN on key queries to show index usage
EXPLAIN SELECT * FROM Transactions WHERE account_id = 4 AND created_at >= '2026-02-01';
EXPLAIN SELECT * FROM Transactions WHERE amount >= 10000;
EXPLAIN SELECT * FROM FraudAlerts WHERE status = 'Open' AND severity = 'Critical';
EXPLAIN SELECT * FROM Customers WHERE national_id = '29001011234567';

-- ============================================================
-- SECTION L: USER ROLES & ACCESS CONTROL
-- ============================================================

-- Create roles (MySQL 8.0+)
CREATE ROLE IF NOT EXISTS 'fraud_admin', 'fraud_analyst', 'bank_teller';

-- Admin: Full access
GRANT ALL PRIVILEGES ON fraud_detection_db.* TO 'fraud_admin';

-- Analyst: Read all + write alerts/reports
GRANT SELECT ON fraud_detection_db.* TO 'fraud_analyst';
GRANT INSERT, UPDATE ON fraud_detection_db.FraudAlerts TO 'fraud_analyst';
GRANT INSERT, UPDATE ON fraud_detection_db.FraudReports TO 'fraud_analyst';
GRANT INSERT, UPDATE ON fraud_detection_db.FlaggedAccounts TO 'fraud_analyst';
GRANT INSERT ON fraud_detection_db.AuditLog TO 'fraud_analyst';

-- Teller: Read-only on transactions and customers
GRANT SELECT ON fraud_detection_db.Transactions TO 'bank_teller';
GRANT SELECT ON fraud_detection_db.Customers TO 'bank_teller';
GRANT SELECT ON fraud_detection_db.Accounts TO 'bank_teller';

-- Create sample users with roles
CREATE USER IF NOT EXISTS 'admin_user'@'localhost' IDENTIFIED BY 'Admin@Secure123';
CREATE USER IF NOT EXISTS 'analyst_user'@'localhost' IDENTIFIED BY 'Analyst@Pass456';
CREATE USER IF NOT EXISTS 'teller_user'@'localhost' IDENTIFIED BY 'Teller@Pass789';

GRANT 'fraud_admin' TO 'admin_user'@'localhost';
GRANT 'fraud_analyst' TO 'analyst_user'@'localhost';
GRANT 'bank_teller' TO 'teller_user'@'localhost';

FLUSH PRIVILEGES;

-- Final verification
SELECT 'DATABASE SETUP COMPLETE' AS status;
SELECT TABLE_NAME, TABLE_ROWS FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'fraud_detection_db';
SELECT * FROM vw_fraud_dashboard;
