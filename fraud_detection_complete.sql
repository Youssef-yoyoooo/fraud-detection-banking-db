-- ============================================================
-- FRAUD DETECTION IN BANKING TRANSACTIONS
-- Fundamentals of Database Systems (CSE462a) â€” Spring 2026
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
USE fraud_detection_db;

-- BRANCHES (20 rows)
INSERT INTO Branches (branch_name, city, region, manager_name, phone) VALUES
('Downtown Main','Cairo','North','Ahmed Hassan','01001111111'),
('Zamalek Branch','Cairo','North','Sara Ibrahim','01002222222'),
('Maadi Branch','Cairo','South','Omar Khalil','01003333333'),
('Alexandria Central','Alexandria','West','Layla Farouk','01004444444'),
('Smouha Branch','Alexandria','West','Tarek Nabil','01005555555'),
('Mansoura Branch','Mansoura','Delta','Heba Mostafa','01006666666'),
('Tanta Branch','Tanta','Delta','Youssef Ali','01007777777'),
('Assiut Branch','Assiut','Upper','Nour Adel','01008888888'),
('Luxor Branch','Luxor','Upper','Mona Saeed','01009999999'),
('Hurghada Branch','Hurghada','Red Sea','Karim Waheed','01010000000'),
('Nasr City Branch','Cairo','East','Dina Gamal','01011111111'),
('Heliopolis Branch','Cairo','East','Rami Fathy','01012222222'),
('Giza Branch','Giza','West','Fatma Rizk','01013333333'),
('6th October Branch','Giza','West','Amr Salah','01014444444'),
('New Capital Branch','New Capital','East','Salma Hany','01015555555'),
('Port Said Branch','Port Said','Canal','Hassan Mahmoud','01016666666'),
('Suez Branch','Suez','Canal','Aya Khaled','01017777777'),
('Ismailia Branch','Ismailia','Canal','Wael Tawfik','01018888888'),
('Sohag Branch','Sohag','Upper','Mariam Zaki','01019999999'),
('Damietta Branch','Damietta','Delta','Khaled Youssef','01020000000');

-- CUSTOMERS (25 rows)
INSERT INTO Customers (national_id, first_name, last_name, email, phone, address, city, date_of_birth, risk_score) VALUES
('29001011234567','Mohamed','El-Sayed','mohamed.s@email.com','01100000001','15 Tahrir St','Cairo','1990-01-01',5),
('29105221234567','Fatma','Ahmed','fatma.a@email.com','01100000002','22 Corniche Rd','Alexandria','1991-05-22',10),
('28803151234567','Ali','Hassan','ali.h@email.com','01100000003','8 Ramsis St','Cairo','1988-03-15',70),
('29507081234567','Nour','Ibrahim','nour.i@email.com','01100000004','45 Gaza St','Mansoura','1995-07-08',3),
('29209121234567','Youssef','Kamal','youssef.k@email.com','01100000005','11 Saad Zaghloul','Tanta','1992-09-12',15),
('28711251234567','Sara','Mahmoud','sara.m@email.com','01100000006','33 Sphinx Ave','Giza','1987-11-25',85),
('29402181234567','Omar','Fathy','omar.f@email.com','01100000007','7 Marina Blvd','Hurghada','1994-02-18',2),
('29606301234567','Hana','Nabil','hana.n@email.com','01100000008','19 University St','Assiut','1996-06-30',8),
('28504141234567','Khaled','Rizk','khaled.r@email.com','01100000009','27 Station Rd','Luxor','1985-04-14',45),
('29308221234567','Dina','Saeed','dina.s@email.com','01100000010','5 Canal St','Suez','1993-08-22',12),
('29110051234567','Tarek','Adel','tarek.a@email.com','01100000011','41 Garden City','Cairo','1991-10-05',60),
('28907171234567','Mariam','Gamal','mariam.g@email.com','01100000012','14 Cleopatra St','Alexandria','1989-07-17',7),
('29703261234567','Amr','Salah','amr.s@email.com','01100000013','9 Orabi Sq','Cairo','1997-03-26',20),
('28601091234567','Layla','Tawfik','layla.t@email.com','01100000014','36 Port St','Port Said','1986-01-09',30),
('29504021234567','Hassan','Waheed','hassan.w@email.com','01100000015','28 Liberty St','Ismailia','1995-04-02',4),
('29812121234567','Aya','Khalil','aya.k@email.com','01100000016','17 Peace Rd','Damietta','1998-12-12',6),
('28408201234567','Wael','Mostafa','wael.m@email.com','01100000017','23 Pharaoh Ave','Sohag','1984-08-20',55),
('29206151234567','Salma','Farouk','salma.f@email.com','01100000018','31 Nile View','Cairo','1992-06-15',9),
('29901031234567','Rami','Zaki','rami.z@email.com','01100000019','12 October St','Giza','1999-01-03',11),
('28702281234567','Mona','Hany','mona.h@email.com','01100000020','44 Revolution St','Cairo','1987-02-28',40),
('29405111234567','Karim','Ali','karim.a@email.com','01100000021','6 Sphinx St','Giza','1994-05-11',75),
('29108191234567','Heba','Youssef','heba.y@email.com','01100000022','29 Delta Rd','Mansoura','1991-08-19',3),
('28810071234567','Nabil','Mahmoud','nabil.m@email.com','01100000023','18 Harbor St','Alexandria','1988-10-07',22),
('29607241234567','Dalia','Hassan','dalia.h@email.com','01100000024','35 Palm St','Hurghada','1996-07-24',14),
('29303161234567','Fady','Ibrahim','fady.i@email.com','01100000025','21 Mountain Rd','Assiut','1993-03-16',8);

-- ACCOUNTS (25 rows)
INSERT INTO Accounts (customer_id, branch_id, account_number, account_type, balance, currency, status) VALUES
(1,1,'ACC-0001-SAV','Savings',25000.00,'USD','Active'),
(1,1,'ACC-0001-CHK','Checking',8500.00,'USD','Active'),
(2,4,'ACC-0002-SAV','Savings',42000.00,'USD','Active'),
(3,1,'ACC-0003-BUS','Business',150000.00,'USD','Frozen'),
(4,6,'ACC-0004-SAV','Savings',12000.00,'USD','Active'),
(5,7,'ACC-0005-CHK','Checking',6700.00,'USD','Active'),
(6,13,'ACC-0006-BUS','Business',320000.00,'USD','Suspended'),
(7,10,'ACC-0007-SAV','Savings',18500.00,'USD','Active'),
(8,8,'ACC-0008-CHK','Checking',3200.00,'USD','Active'),
(9,9,'ACC-0009-SAV','Savings',55000.00,'USD','Active'),
(10,17,'ACC-0010-CHK','Checking',9800.00,'USD','Active'),
(11,11,'ACC-0011-BUS','Business',87000.00,'USD','Active'),
(12,4,'ACC-0012-SAV','Savings',31000.00,'USD','Active'),
(13,1,'ACC-0013-CHK','Checking',4500.00,'USD','Active'),
(14,16,'ACC-0014-SAV','Savings',22000.00,'USD','Active'),
(15,18,'ACC-0015-CHK','Checking',7800.00,'USD','Active'),
(16,20,'ACC-0016-SAV','Savings',14000.00,'USD','Active'),
(17,19,'ACC-0017-BUS','Business',95000.00,'USD','Active'),
(18,1,'ACC-0018-SAV','Savings',28000.00,'USD','Active'),
(19,14,'ACC-0019-CHK','Checking',5600.00,'USD','Active'),
(20,11,'ACC-0020-BUS','Business',110000.00,'USD','Active'),
(21,13,'ACC-0021-CRD','Credit',45000.00,'USD','Active'),
(22,6,'ACC-0022-SAV','Savings',19000.00,'USD','Active'),
(23,5,'ACC-0023-CHK','Checking',8200.00,'USD','Active'),
(24,10,'ACC-0024-SAV','Savings',16500.00,'USD','Active');

-- USERS (20 rows)
INSERT INTO Users (username, password_hash, role, email, full_name, is_active) VALUES
('admin1',SHA2('AdminPass123!',256),'Admin','admin1@bank.com','System Administrator',1),
('admin2',SHA2('AdminPass456!',256),'Admin','admin2@bank.com','Chief Security Officer',1),
('analyst1',SHA2('AnalystP@ss1',256),'Analyst','analyst1@bank.com','Nora Samy',1),
('analyst2',SHA2('AnalystP@ss2',256),'Analyst','analyst2@bank.com','Mostafa Reda',1),
('analyst3',SHA2('AnalystP@ss3',256),'Analyst','analyst3@bank.com','Yasmin Helal',1),
('analyst4',SHA2('AnalystP@ss4',256),'Analyst','analyst4@bank.com','Hazem Fouad',1),
('analyst5',SHA2('AnalystP@ss5',256),'Analyst','analyst5@bank.com','Reem Barakat',1),
('teller1',SHA2('TellerP@ss1',256),'Teller','teller1@bank.com','Ahmad Teller',1),
('teller2',SHA2('TellerP@ss2',256),'Teller','teller2@bank.com','Basma Teller',1),
('teller3',SHA2('TellerP@ss3',256),'Teller','teller3@bank.com','Gamila Teller',1),
('teller4',SHA2('TellerP@ss4',256),'Teller','teller4@bank.com','Sherif Teller',1),
('teller5',SHA2('TellerP@ss5',256),'Teller','teller5@bank.com','Noha Teller',1),
('auditor1',SHA2('AuditP@ss1',256),'Auditor','auditor1@bank.com','Samir Auditor',1),
('auditor2',SHA2('AuditP@ss2',256),'Auditor','auditor2@bank.com','Lamia Auditor',1),
('analyst6',SHA2('AnalystP@ss6',256),'Analyst','analyst6@bank.com','Ziad Mansour',1),
('teller6',SHA2('TellerP@ss6',256),'Teller','teller6@bank.com','Hoda Teller',1),
('analyst7',SHA2('AnalystP@ss7',256),'Analyst','analyst7@bank.com','Tamer Shawky',1),
('admin3',SHA2('AdminPass789!',256),'Admin','admin3@bank.com','Branch IT Admin',1),
('auditor3',SHA2('AuditP@ss3',256),'Auditor','auditor3@bank.com','Amir Auditor',1),
('analyst8',SHA2('AnalystP@ss8',256),'Analyst','analyst8@bank.com','Rana Medhat',1);

-- FRAUD RULES (20 rows)
INSERT INTO FraudRules (rule_name, description, threshold_amount, time_window_minutes, max_frequency, is_active) VALUES
('High Value Single','Single transaction exceeds threshold',10000.00,NULL,NULL,1),
('Rapid Fire','Too many transactions in short period',NULL,10,5,1),
('Geo Anomaly','Transaction from unusual location',NULL,60,NULL,1),
('Midnight Activity','Transactions between 1-5 AM',5000.00,NULL,NULL,1),
('New Account Large','Large tx within 7 days of account opening',5000.00,10080,1,1),
('Cross Border','International transaction pattern',8000.00,NULL,NULL,1),
('Round Amount','Suspicious round amounts',NULL,NULL,3,1),
('Channel Switch','Rapid channel switching',NULL,30,3,1),
('Dormant Activation','Dormant account sudden activity',1000.00,NULL,NULL,1),
('Velocity Spike','Sudden increase in tx frequency',NULL,1440,10,1),
('Split Transaction','Potential structuring/smurfing',9500.00,60,3,1),
('ATM Withdraw Limit','Multiple ATM withdrawals',2000.00,60,3,1),
('Failed Then Success','Multiple failures then success',NULL,15,3,1),
('Device Change','New device for transaction',NULL,NULL,NULL,1),
('IP Mismatch','IP location mismatch',NULL,NULL,NULL,1),
('Beneficiary Pattern','New beneficiary large transfer',15000.00,NULL,NULL,1),
('Balance Drain','Account balance drained quickly',NULL,120,NULL,1),
('POS Anomaly','Unusual POS transaction pattern',3000.00,30,5,1),
('Refund Abuse','Excessive refund requests',500.00,1440,5,1),
('Login Failure Spike','Multiple failed logins',NULL,30,5,1);
USE fraud_detection_db;

-- TRANSACTIONS (30 rows â€” mix of normal and suspicious patterns)
INSERT INTO Transactions (account_id, transaction_type, amount, counterparty_account, channel, ip_address, device_id, location, description, status, created_at) VALUES
(1,'Deposit',2500.00,NULL,'Branch',NULL,NULL,'Cairo','Salary deposit','Completed','2026-01-15 09:30:00'),
(1,'Withdrawal',500.00,NULL,'ATM','10.0.0.1','DEV-001','Cairo','Cash withdrawal','Completed','2026-01-16 14:20:00'),
(1,'Transfer',1200.00,'ACC-0002-SAV','Online','192.168.1.10','DEV-001','Cairo','Rent payment','Completed','2026-01-17 11:00:00'),
(2,'Deposit',3500.00,NULL,'Branch',NULL,NULL,'Alexandria','Salary deposit','Completed','2026-01-15 10:00:00'),
(3,'Transfer',45000.00,'EXT-9999-001','Online','85.120.44.12','DEV-099','Lagos','Large overseas transfer','Completed','2026-02-01 02:30:00'),
(3,'Transfer',42000.00,'EXT-9999-002','Online','85.120.44.12','DEV-099','Lagos','Second large transfer','Completed','2026-02-01 02:45:00'),
(3,'Withdrawal',9500.00,NULL,'ATM','10.0.0.5','DEV-003','Cairo','ATM cash out','Completed','2026-02-01 03:10:00'),
(4,'Deposit',1500.00,NULL,'Mobile','172.16.0.1','DEV-004','Mansoura','Freelance income','Completed','2026-02-05 16:00:00'),
(5,'Payment',230.00,NULL,'POS','10.0.1.1','DEV-005','Tanta','Grocery shopping','Completed','2026-02-10 12:30:00'),
(6,'Transfer',85000.00,'EXT-8888-001','Online','103.55.12.8','DEV-100','Dubai','International wire','Completed','2026-02-12 01:15:00'),
(6,'Transfer',78000.00,'EXT-8888-002','Online','103.55.12.8','DEV-100','Dubai','Second wire same night','Completed','2026-02-12 01:30:00'),
(6,'Transfer',65000.00,'EXT-8888-003','Mobile','41.22.8.100','DEV-101','Nairobi','Third wire diff location','Completed','2026-02-12 02:00:00'),
(7,'Deposit',4200.00,NULL,'Branch',NULL,NULL,'Hurghada','Business income','Completed','2026-02-15 09:00:00'),
(8,'Withdrawal',200.00,NULL,'ATM','10.0.2.1','DEV-008','Assiut','Small withdrawal','Completed','2026-02-18 17:45:00'),
(9,'Transfer',3000.00,'ACC-0001-SAV','Online','192.168.5.1','DEV-009','Luxor','Friend payment','Completed','2026-02-20 13:00:00'),
(10,'Payment',450.00,NULL,'POS','10.0.3.1','DEV-010','Suez','Restaurant bill','Completed','2026-02-22 20:30:00'),
(11,'Transfer',15000.00,'EXT-7777-001','Online','192.168.10.1','DEV-011','Cairo','Supplier payment','Completed','2026-02-25 10:00:00'),
(11,'Transfer',14800.00,'EXT-7777-002','Online','192.168.10.1','DEV-011','Cairo','Second supplier payment','Completed','2026-02-25 10:05:00'),
(11,'Transfer',14900.00,'EXT-7777-003','Online','192.168.10.1','DEV-011','Cairo','Third payment 5min later','Completed','2026-02-25 10:10:00'),
(12,'Deposit',5000.00,NULL,'Branch',NULL,NULL,'Alexandria','Savings deposit','Completed','2026-03-01 11:00:00'),
(13,'Withdrawal',300.00,NULL,'ATM','10.0.4.1','DEV-013','Cairo','Cash for lunch','Completed','2026-03-03 12:15:00'),
(14,'Transfer',8500.00,'EXT-6666-001','Online','196.20.1.5','DEV-014','Port Said','Equipment purchase','Completed','2026-03-05 15:30:00'),
(15,'Deposit',2200.00,NULL,'Mobile','172.16.1.1','DEV-015','Ismailia','Side job income','Completed','2026-03-07 09:45:00'),
(16,'Payment',180.00,NULL,'POS','10.0.5.1','DEV-016','Damietta','Pharmacy purchase','Completed','2026-03-10 18:00:00'),
(17,'Transfer',25000.00,'EXT-5555-001','Online','45.33.12.7','DEV-017','Sohag','Land payment','Completed','2026-03-12 14:00:00'),
(18,'Deposit',3800.00,NULL,'Branch',NULL,NULL,'Cairo','Monthly salary','Completed','2026-03-15 09:30:00'),
(19,'Withdrawal',1000.00,NULL,'ATM','10.0.6.1','DEV-019','Giza','Weekend cash','Completed','2026-03-17 19:00:00'),
(20,'Transfer',50000.00,'EXT-4444-001','Online','89.44.55.1','DEV-020','Cairo','Bulk order payment','Completed','2026-03-20 03:00:00'),
(21,'Payment',9800.00,NULL,'POS','10.0.7.1','DEV-021','Giza','Electronics purchase','Completed','2026-03-22 16:30:00'),
(21,'Payment',9700.00,NULL,'POS','10.0.7.2','DEV-021','Giza','Second large POS 1hr','Completed','2026-03-22 17:30:00');

-- FRAUD ALERTS (22 rows)
INSERT INTO FraudAlerts (transaction_id, rule_id, alert_type, severity, description, status, created_at, resolved_at, resolved_by) VALUES
(5,1,'High_Value','Critical','Transfer of $45,000 to overseas account at 2:30 AM','Confirmed_Fraud','2026-02-01 02:31:00','2026-02-03 10:00:00',3),
(6,1,'High_Value','Critical','Second $42,000 transfer within 15 minutes','Confirmed_Fraud','2026-02-01 02:46:00','2026-02-03 10:00:00',3),
(7,12,'Velocity','High','ATM withdrawal after two large transfers at night','Under_Review','2026-02-01 03:11:00',NULL,NULL),
(5,4,'Pattern','Critical','Transaction during midnight hours 1-5 AM','Confirmed_Fraud','2026-02-01 02:31:00','2026-02-03 10:00:00',3),
(6,4,'Pattern','Critical','Second midnight transaction','Confirmed_Fraud','2026-02-01 02:46:00','2026-02-03 10:00:00',3),
(10,1,'High_Value','Critical','$85,000 international wire at 1:15 AM','Open','2026-02-12 01:16:00',NULL,NULL),
(11,1,'High_Value','Critical','$78,000 transfer 15 min after first','Open','2026-02-12 01:31:00',NULL,NULL),
(12,3,'Geographic','Critical','Third transfer from different continent within 1hr','Open','2026-02-12 02:01:00',NULL,NULL),
(10,4,'Pattern','High','Midnight international wire','Under_Review','2026-02-12 01:16:00',NULL,NULL),
(11,2,'Velocity','High','Rapid successive transfers same session','Under_Review','2026-02-12 01:31:00',NULL,NULL),
(17,11,'High_Value','Medium','$15,000 to new beneficiary','Resolved','2026-02-25 10:01:00','2026-02-27 14:00:00',4),
(18,2,'Velocity','High','Three transfers within 10 minutes','Under_Review','2026-02-25 10:06:00',NULL,NULL),
(19,2,'Velocity','High','Third rapid transfer in sequence','Under_Review','2026-02-25 10:11:00',NULL,NULL),
(22,6,'High_Value','Medium','$8,500 cross-border transfer','False_Positive','2026-03-05 15:31:00','2026-03-06 09:00:00',5),
(25,1,'High_Value','Medium','$25,000 single transfer','Resolved','2026-03-12 14:01:00','2026-03-14 11:00:00',4),
(28,1,'High_Value','High','$50,000 bulk transfer at 3 AM','Open','2026-03-20 03:01:00',NULL,NULL),
(28,4,'Pattern','High','Large transfer during midnight hours','Open','2026-03-20 03:01:00',NULL,NULL),
(29,18,'Pattern','Medium','Large POS purchase $9,800','False_Positive','2026-03-22 16:31:00','2026-03-23 10:00:00',5),
(30,2,'Velocity','Medium','Second large POS within 1 hour','Open','2026-03-22 17:31:00',NULL,NULL),
(12,15,'Geographic','Critical','IP location mismatch Dubai vs Nairobi','Open','2026-02-12 02:01:00',NULL,NULL),
(6,11,'Pattern','High','Potential structuring - amounts near $10k boundary','Confirmed_Fraud','2026-02-01 02:46:00','2026-02-05 09:00:00',3),
(7,9,'Pattern','Medium','Account was dormant for 6 months before large activity','Under_Review','2026-02-01 03:11:00',NULL,NULL);

-- FLAGGED ACCOUNTS (20 rows)
INSERT INTO FlaggedAccounts (account_id, reason, risk_level, reviewed_by, review_status, notes) VALUES
(4,'Multiple confirmed fraud alerts','Critical',3,'Confirmed','Account frozen pending investigation'),
(7,'International transfers at unusual hours','Critical',NULL,'Pending','Awaiting analyst review'),
(12,'Rapid successive transfers pattern','High',4,'Under_Review','Monitoring for 30 days'),
(20,'Large bulk transfer at 3 AM','High',NULL,'Pending','Flagged by automated rule'),
(21,'Multiple large POS transactions','Medium',5,'Cleared','Verified as legitimate business purchases'),
(2,'Associated with flagged customer','Low',4,'Cleared','No suspicious activity found'),
(10,'Unusual ATM activity pattern','Medium',NULL,'Pending','Auto-flagged by velocity rule'),
(14,'Cross-border transaction to new beneficiary','Medium',5,'Cleared','Verified trade payment'),
(17,'Large land payment from business account','Low',4,'Cleared','Documentation verified'),
(11,'Business account rapid fire transfers','High',3,'Confirmed','Under extended monitoring'),
(1,'Counterparty to flagged account ACC-0003','Low',4,'Cleared','No direct involvement'),
(9,'Received transfer from flagged customer','Medium',NULL,'Pending','Under review'),
(5,'Multiple small transactions pattern','Low',5,'Cleared','Normal spending behavior'),
(8,'Login from multiple devices','Low',NULL,'Pending','Checking device history'),
(15,'New account with immediate large deposit','Medium',3,'Under_Review','Verifying source of funds'),
(3,'Linked to external fraud ring report','Critical',3,'Confirmed','SAR filed'),
(19,'Cash withdrawal pattern anomaly','Low',4,'Cleared','Student - normal pattern'),
(23,'Multiple city transactions same day','Medium',NULL,'Pending','Checking travel records'),
(24,'Deposit-withdraw-transfer cycle','High',NULL,'Pending','Potential money laundering pattern'),
(16,'Unusual activity for dormant account','Medium',5,'Under_Review','Account reactivated recently');

-- FRAUD REPORTS (20 rows)
INSERT INTO FraudReports (alert_id, investigator_id, findings, recommendation, evidence_summary, status) VALUES
(1,3,'Confirmed unauthorized access. Account compromised via phishing.','Freeze_Account','IP trace shows Nigerian proxy. Customer confirmed no travel.','Approved'),
(2,3,'Same session as alert #1. Funds moved to mule account.','File_SAR','Same IP and device as first transfer.','Approved'),
(4,3,'Part of coordinated midnight attack on account.','Freeze_Account','Timestamps confirm automated tool usage.','Approved'),
(5,3,'Continuation of midnight fraud pattern.','Freeze_Account','Device fingerprint matches known fraud tool.','Approved'),
(11,4,'Legitimate business supplier payments verified.','Close_Case','Invoices and contracts provided by customer.','Approved'),
(14,5,'Regular trade import payment to verified supplier.','Close_Case','Trade license and supplier contract verified.','Approved'),
(15,4,'Customer verified large land purchase with documentation.','Close_Case','Sale contract and notary documents provided.','Approved'),
(18,5,'Customer runs electronics retail business. Normal POS volume.','Close_Case','Business license and POS merchant agreement verified.','Approved'),
(21,3,'Transaction amounts structured to avoid $10k reporting threshold.','File_SAR','Pattern analysis shows deliberate splitting.','Approved'),
(6,4,'Investigation ongoing. Account holder unreachable.','Escalate','Multiple contact attempts failed. Possible identity theft.','Submitted'),
(7,4,'Same session as alert #6. Escalation recommended.','Escalate','Linked to same IP cluster as confirmed fraud.','Submitted'),
(8,4,'Geographic impossibility: Dubai to Nairobi in 45 minutes.','Freeze_Account','IP geolocation confirms two different continents.','Submitted'),
(9,3,'Midnight pattern consistent with automated fraud.','Monitor','Similar pattern to confirmed case on account 4.','Draft'),
(10,3,'Velocity exceeds normal behavior by 400%.','Freeze_Account','Historical analysis shows max 2 transfers per month.','Draft'),
(12,4,'Three business transfers in 10 minutes to new beneficiaries.','Monitor','Beneficiary accounts opened recently.','Submitted'),
(13,4,'Part of rapid transfer sequence. Possible layering.','Escalate','Links to shell company accounts.','Submitted'),
(16,5,'Bulk payment at unusual hour. Customer not yet contacted.','Monitor','Similar to previous confirmed fraud patterns.','Draft'),
(17,5,'Associated with midnight transfer alert.','Monitor','Will review with daytime transaction patterns.','Draft'),
(19,4,'Second large POS in same location within 1 hour.','Close_Case','Appears to be split payment at electronics store.','Submitted'),
(22,3,'Account dormant 6 months then sudden $9,500 ATM withdrawal.','Monitor','Checking if customer relocated or account sold.','Draft');

-- LOGIN ATTEMPTS (25 rows)
INSERT INTO LoginAttempts (user_id, ip_address, success, attempted_at) VALUES
(1,'10.0.0.1',1,'2026-01-10 08:00:00'),
(1,'10.0.0.1',1,'2026-01-11 08:05:00'),
(3,'10.0.1.1',1,'2026-01-10 09:00:00'),
(3,'10.0.1.1',1,'2026-01-11 09:10:00'),
(4,'10.0.1.2',0,'2026-01-12 08:30:00'),
(4,'10.0.1.2',0,'2026-01-12 08:31:00'),
(4,'10.0.1.2',0,'2026-01-12 08:32:00'),
(4,'10.0.1.2',1,'2026-01-12 08:35:00'),
(8,'10.0.2.1',1,'2026-01-15 07:55:00'),
(9,'10.0.2.2',1,'2026-01-15 08:00:00'),
(2,'10.0.0.2',1,'2026-01-16 09:00:00'),
(5,'10.0.1.3',1,'2026-01-17 10:00:00'),
(6,'10.0.1.4',0,'2026-01-18 11:00:00'),
(6,'10.0.1.4',1,'2026-01-18 11:02:00'),
(7,'10.0.1.5',1,'2026-01-19 08:30:00'),
(13,'10.0.3.1',1,'2026-01-20 14:00:00'),
(14,'10.0.3.2',1,'2026-01-21 09:15:00'),
(10,'10.0.2.3',0,'2026-02-01 03:00:00'),
(10,'10.0.2.3',0,'2026-02-01 03:01:00'),
(10,'10.0.2.3',0,'2026-02-01 03:02:00'),
(10,'10.0.2.3',0,'2026-02-01 03:03:00'),
(10,'10.0.2.3',0,'2026-02-01 03:04:00'),
(10,'85.120.44.12',1,'2026-02-01 03:05:00'),
(15,'10.0.4.1',1,'2026-02-05 08:00:00'),
(17,'10.0.4.2',1,'2026-02-10 09:00:00');

-- AUDIT LOG (20 rows)
INSERT INTO AuditLog (user_id, action, table_affected, record_id, old_value, new_value, ip_address, created_at) VALUES
(1,'INSERT','Users',1,NULL,'Created admin1 account','10.0.0.1','2026-01-01 08:00:00'),
(1,'INSERT','FraudRules',1,NULL,'Created High Value Single rule','10.0.0.1','2026-01-02 09:00:00'),
(3,'INSERT','FraudAlerts',1,NULL,'Alert created for txn 5','10.0.1.1','2026-02-01 02:31:00'),
(3,'UPDATE','FraudAlerts',1,'status=Open','status=Confirmed_Fraud','10.0.1.1','2026-02-03 10:00:00'),
(3,'UPDATE','Accounts',4,'status=Active','status=Frozen','10.0.1.1','2026-02-03 10:05:00'),
(3,'INSERT','FraudReports',1,NULL,'Report created for alert 1','10.0.1.1','2026-02-03 10:10:00'),
(4,'INSERT','FraudAlerts',11,NULL,'Alert for supplier payment','10.0.1.2','2026-02-25 10:01:00'),
(4,'UPDATE','FraudAlerts',11,'status=Open','status=Resolved','10.0.1.2','2026-02-27 14:00:00'),
(5,'INSERT','FraudAlerts',14,NULL,'Cross-border alert','10.0.1.3','2026-03-05 15:31:00'),
(5,'UPDATE','FraudAlerts',14,'status=Open','status=False_Positive','10.0.1.3','2026-03-06 09:00:00'),
(1,'UPDATE','FraudRules',2,'max_frequency=3','max_frequency=5','10.0.0.1','2026-03-10 11:00:00'),
(1,'INSERT','Users',15,NULL,'Created analyst6 account','10.0.0.1','2026-03-12 08:00:00'),
(3,'LOGIN','Users',3,NULL,'Successful login','10.0.1.1','2026-03-15 09:00:00'),
(4,'LOGIN','Users',4,NULL,'Successful login','10.0.1.2','2026-03-15 09:05:00'),
(3,'INSERT','FlaggedAccounts',1,NULL,'Flagged account 4','10.0.1.1','2026-02-03 10:15:00'),
(4,'UPDATE','FlaggedAccounts',3,'review_status=Pending','review_status=Under_Review','10.0.1.2','2026-02-26 10:00:00'),
(1,'DELETE','LoginAttempts',NULL,'Purged old login records',NULL,'10.0.0.1','2026-03-01 06:00:00'),
(5,'QUERY','Transactions',NULL,NULL,'Exported fraud report data','10.0.1.3','2026-03-10 14:00:00'),
(2,'UPDATE','Users',6,'is_active=1','is_active=0','10.0.0.2','2026-03-18 16:00:00'),
(1,'INSERT','Branches',20,NULL,'Created Damietta Branch','10.0.0.1','2026-01-05 10:00:00');
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
