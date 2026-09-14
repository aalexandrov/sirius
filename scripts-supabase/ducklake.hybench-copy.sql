.echo on

-- Create schema
DROP SCHEMA IF EXISTS ducklake.hybench_sf0010 CASCADE;
CREATE SCHEMA ducklake.hybench_sf0010;

-- Create tables
CREATE TABLE ducklake.hybench_sf0010.checking AS
SELECT * FROM hybench.sf0010.checking LIMIT 0;

CREATE TABLE ducklake.hybench_sf0010.checkingaccount AS
SELECT * FROM hybench.sf0010.checkingaccount LIMIT 0;

CREATE TABLE ducklake.hybench_sf0010.company AS
SELECT * FROM hybench.sf0010.company LIMIT 0;

CREATE TABLE ducklake.hybench_sf0010.customer AS
SELECT * FROM hybench.sf0010.customer LIMIT 0;

CREATE TABLE ducklake.hybench_sf0010.loanapps AS
SELECT * FROM hybench.sf0010.loanapps LIMIT 0;

CREATE TABLE ducklake.hybench_sf0010.loantrans AS
SELECT * FROM hybench.sf0010.loantrans LIMIT 0;

CREATE TABLE ducklake.hybench_sf0010.savingaccount AS
SELECT * FROM hybench.sf0010.savingaccount LIMIT 0;

CREATE TABLE ducklake.hybench_sf0010.transfer AS
SELECT * FROM hybench.sf0010.transfer LIMIT 0;

-- Set sort order
ALTER TABLE ducklake.hybench_sf0010.transfer SET SORTED BY (timestamp ASC);

-- Populate tables
INSERT INTO ducklake.hybench_sf0010.checking
SELECT * FROM hybench.sf0010.checking;

INSERT INTO ducklake.hybench_sf0010.checkingaccount
SELECT * FROM hybench.sf0010.checkingaccount;

INSERT INTO ducklake.hybench_sf0010.company
SELECT * FROM hybench.sf0010.company;

INSERT INTO ducklake.hybench_sf0010.customer
SELECT * FROM hybench.sf0010.customer;

INSERT INTO ducklake.hybench_sf0010.loanapps
SELECT * FROM hybench.sf0010.loanapps;

INSERT INTO ducklake.hybench_sf0010.loantrans
SELECT * FROM hybench.sf0010.loantrans;

INSERT INTO ducklake.hybench_sf0010.savingaccount
SELECT * FROM hybench.sf0010.savingaccount;

INSERT INTO ducklake.hybench_sf0010.transfer
SELECT * FROM hybench.sf0010.transfer ORDER BY timestamp;
