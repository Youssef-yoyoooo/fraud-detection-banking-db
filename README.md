# Fraud Detection in Banking Transactions

## Project Overview
This repository contains a comprehensive relational database system designed to monitor, detect, and report fraudulent activities in banking transactions. The system utilizes a structured schema to track customers, accounts, and transactions while applying automated rules to identify anomalies.

## Key Features
- Transaction tracking with metadata (IP address, device ID, location).
- Automated fraud detection via stored procedures (High-Value, Velocity, Geographic anomalies).
- Real-time audit logging and risk scoring for accounts.
- Role-based access control for administrators, analysts, and tellers.
- Comprehensive reporting system for fraud investigations.

## Database Schema
The database consists of 11 normalized tables:
- Branches
- Customers
- Accounts
- Transactions
- FraudRules
- Users
- FraudAlerts
- FlaggedAccounts
- FraudReports
- AuditLog
- LoginAttempts

## Implementation Details
The project is implemented in MySQL. It includes:
- DDL scripts for table creation and indexing.
- DML scripts with sample data illustrating various fraud patterns.
- Stored procedures for complex logic and transaction processing.
- Triggers for automated monitoring and integrity checks.
- Views for dashboard summaries and risk profiles.

## Usage
To set up the database:
1. Ensure MySQL Server is installed and running.
2. Execute the `fraud_detection_complete.sql` script to create the schema and populate it with sample data.
3. Use the provided query scripts in `04_queries.sql` to test the system functionality.
