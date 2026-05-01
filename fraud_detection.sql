-- ============================================================
-- FRAUD DETECTION IN BANKING TRANSACTIONS
-- Fundamentals of Database Systems (CSE462a) — Spring 2026
-- ============================================================

DROP DATABASE IF EXISTS fraud_detection_db;
CREATE DATABASE fraud_detection_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE fraud_detection_db;

-- ============================================================
-- SECTION A: TABLE CREATION (DDL)
-- ============================================================

CREATE TABLE Branches (
    branch_id INT AUTO_INCREMENT PRIMARY KEY,
    branch_name VARCHAR(100) NOT NULL,
    city VARCHAR(50) NOT NULL,
    region VARCHAR(50) NOT NULL,
    manager_name VARCHAR(100),
    phone VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    national_id VARCHAR(20) NOT NULL UNIQUE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20),
    address VARCHAR(200),
    city VARCHAR(50),
    date_of_birth DATE,
    risk_score INT DEFAULT 0 CHECK (risk_score BETWEEN 0 AND 100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Accounts (
    account_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    branch_id INT NOT NULL,
    account_number VARCHAR(20) NOT NULL UNIQUE,
    account_type ENUM('Savings', 'Checking', 'Business', 'Credit') NOT NULL,
    balance DECIMAL(15,2) DEFAULT 0.00,
    currency VARCHAR(3) DEFAULT 'USD',
    status ENUM('Active', 'Suspended', 'Closed', 'Frozen') DEFAULT 'Active',
    opened_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id) ON DELETE CASCADE,
    FOREIGN KEY (branch_id) REFERENCES Branches(branch_id)
);

CREATE TABLE Transactions (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    account_id INT NOT NULL,
    transaction_type ENUM('Deposit', 'Withdrawal', 'Transfer', 'Payment', 'Refund') NOT NULL,
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    currency VARCHAR(3) DEFAULT 'USD',
    counterparty_account VARCHAR(20),
    channel ENUM('ATM', 'Online', 'Mobile', 'Branch', 'POS') NOT NULL,
    ip_address VARCHAR(45),
    device_id VARCHAR(100),
    location VARCHAR(100),
    description VARCHAR(255),
    status ENUM('Completed', 'Pending', 'Failed', 'Reversed') DEFAULT 'Completed',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (account_id) REFERENCES Accounts(account_id)
);

CREATE TABLE FraudRules (
    rule_id INT AUTO_INCREMENT PRIMARY KEY,
    rule_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    threshold_amount DECIMAL(15,2),
    time_window_minutes INT,
    max_frequency INT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('Admin', 'Analyst', 'Teller', 'Auditor') NOT NULL,
    email VARCHAR(100) UNIQUE,
    full_name VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE FraudAlerts (
    alert_id INT AUTO_INCREMENT PRIMARY KEY,
    transaction_id INT NOT NULL,
    rule_id INT,
    alert_type ENUM('High_Value', 'Velocity', 'Geographic', 'Pattern', 'Manual') NOT NULL,
    severity ENUM('Low', 'Medium', 'High', 'Critical') NOT NULL,
    description TEXT,
    status ENUM('Open', 'Under_Review', 'Confirmed_Fraud', 'False_Positive', 'Resolved') DEFAULT 'Open',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP NULL,
    resolved_by INT,
    FOREIGN KEY (transaction_id) REFERENCES Transactions(transaction_id),
    FOREIGN KEY (rule_id) REFERENCES FraudRules(rule_id),
    FOREIGN KEY (resolved_by) REFERENCES Users(user_id)
);

CREATE TABLE FlaggedAccounts (
    flag_id INT AUTO_INCREMENT PRIMARY KEY,
    account_id INT NOT NULL,
    reason VARCHAR(255) NOT NULL,
    risk_level ENUM('Low', 'Medium', 'High', 'Critical') NOT NULL,
    flagged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reviewed_by INT,
    review_status ENUM('Pending', 'Under_Review', 'Cleared', 'Confirmed') DEFAULT 'Pending',
    notes TEXT,
    FOREIGN KEY (account_id) REFERENCES Accounts(account_id),
    FOREIGN KEY (reviewed_by) REFERENCES Users(user_id)
);

CREATE TABLE FraudReports (
    report_id INT AUTO_INCREMENT PRIMARY KEY,
    alert_id INT NOT NULL,
    investigator_id INT NOT NULL,
    findings TEXT NOT NULL,
    recommendation ENUM('Close_Case', 'Freeze_Account', 'Escalate', 'File_SAR', 'Monitor') NOT NULL,
    evidence_summary TEXT,
    status ENUM('Draft', 'Submitted', 'Approved', 'Rejected') DEFAULT 'Draft',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (alert_id) REFERENCES FraudAlerts(alert_id),
    FOREIGN KEY (investigator_id) REFERENCES Users(user_id)
);

CREATE TABLE AuditLog (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    action ENUM('INSERT', 'UPDATE', 'DELETE', 'LOGIN', 'LOGOUT', 'QUERY') NOT NULL,
    table_affected VARCHAR(50),
    record_id INT,
    old_value TEXT,
    new_value TEXT,
    ip_address VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
);

CREATE TABLE LoginAttempts (
    attempt_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    success BOOLEAN NOT NULL,
    attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
);

-- ============================================================
-- SECTION B: INDEXES FOR QUERY OPTIMIZATION
-- ============================================================

CREATE INDEX idx_transactions_account_date ON Transactions(account_id, created_at);
CREATE INDEX idx_transactions_amount ON Transactions(amount);
CREATE INDEX idx_transactions_status ON Transactions(status);
CREATE INDEX idx_transactions_channel ON Transactions(channel);
CREATE INDEX idx_fraud_alerts_status_severity ON FraudAlerts(status, severity);
CREATE INDEX idx_fraud_alerts_created ON FraudAlerts(created_at);
CREATE INDEX idx_customers_national_id ON Customers(national_id);
CREATE INDEX idx_customers_risk ON Customers(risk_score);
CREATE INDEX idx_accounts_status ON Accounts(status);
CREATE INDEX idx_flagged_accounts_risk ON FlaggedAccounts(risk_level);
CREATE INDEX idx_login_attempts_user ON LoginAttempts(user_id, attempted_at);
CREATE INDEX idx_audit_log_table ON AuditLog(table_affected, created_at);
