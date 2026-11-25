-- Oracle 19c -> Amazon RDS for PostgreSQL 18.6
-- REVIEWED DDL WORKING COPY v1
-- Source: AWS DMS Schema Conversion generated PostgreSQL DDL export
--
-- Changes in this working copy:
--   1. Removed obsolete WITH (OIDS=FALSE) table clauses (12 occurrences).
--   2. Preserved schemas, sequences, tables, indexes, PK/unique/check/FK constraints.
--
-- Explicit pre-deployment items still requiring resolution:
--   * 11 defaults reference aws_oracle_ext.systimestamp(); confirm the required
--     compatibility function/extension exists on RDS, or replace with a reviewed
--     PostgreSQL expression that preserves the source timestamp semantics.
--   * The 11 sequences are retained but are not attached to table columns.
--     Oracle source has no identity columns or sequence column defaults; do not
--     add nextval() defaults until application-side usage is confirmed.
--   * Validate all DDL on the PostgreSQL 18.6 target before production use.
--
-- This file is a reviewed working copy, NOT yet approved for execution.

-- ------------ Write CREATE-DATABASE-stage scripts -----------

CREATE SCHEMA IF NOT EXISTS common;

CREATE SCHEMA IF NOT EXISTS finance;

CREATE SCHEMA IF NOT EXISTS grants;

CREATE SCHEMA IF NOT EXISTS procurement;

-- ------------ Write CREATE-SEQUENCE-stage scripts -----------

CREATE SEQUENCE IF NOT EXISTS common.seq_dim_agency
INCREMENT BY 1
START WITH 9
MAXVALUE 9223372036854775807
MINVALUE 1
NO CYCLE
CACHE 1;

CREATE SEQUENCE IF NOT EXISTS common.seq_dim_geography
INCREMENT BY 1
START WITH 13
MAXVALUE 9223372036854775807
MINVALUE 1
NO CYCLE
CACHE 1;

CREATE SEQUENCE IF NOT EXISTS common.seq_dim_program
INCREMENT BY 1
START WITH 13
MAXVALUE 9223372036854775807
MINVALUE 1
NO CYCLE
CACHE 1;

CREATE SEQUENCE IF NOT EXISTS finance.seq_budget_execution
INCREMENT BY 1
START WITH 10001
MAXVALUE 9223372036854775807
MINVALUE 1
NO CYCLE
CACHE 1;

CREATE SEQUENCE IF NOT EXISTS finance.seq_financial_transaction
INCREMENT BY 1
START WITH 10001
MAXVALUE 9223372036854775807
MINVALUE 1
NO CYCLE
CACHE 1;

CREATE SEQUENCE IF NOT EXISTS grants.seq_dim_recipient
INCREMENT BY 1
START WITH 11
MAXVALUE 9223372036854775807
MINVALUE 1
NO CYCLE
CACHE 1;

CREATE SEQUENCE IF NOT EXISTS grants.seq_fact_grant_application
INCREMENT BY 1
START WITH 3008973
MAXVALUE 9223372036854775807
MINVALUE 1
NO CYCLE
CACHE 1;

CREATE SEQUENCE IF NOT EXISTS procurement.seq_contract
INCREMENT BY 1
START WITH 1001
MAXVALUE 9223372036854775807
MINVALUE 1
NO CYCLE
CACHE 1;

CREATE SEQUENCE IF NOT EXISTS procurement.seq_contract_payment
INCREMENT BY 1
START WITH 100001
MAXVALUE 9223372036854775807
MINVALUE 1
NO CYCLE
CACHE 1;

CREATE SEQUENCE IF NOT EXISTS procurement.seq_purchase_order
INCREMENT BY 1
START WITH 100001
MAXVALUE 9223372036854775807
MINVALUE 1
NO CYCLE
CACHE 1;

CREATE SEQUENCE IF NOT EXISTS procurement.seq_vendor
INCREMENT BY 1
START WITH 101
MAXVALUE 9223372036854775807
MINVALUE 1
NO CYCLE
CACHE 1;

-- ------------ Write CREATE-TABLE-stage scripts -----------

CREATE TABLE common.dim_agency(
    agency_key BIGINT NOT NULL,
    agency_code CHARACTER VARYING(20) NOT NULL,
    agency_name CHARACTER VARYING(150) NOT NULL,
    department_code CHARACTER VARYING(20) NOT NULL,
    department_name CHARACTER VARYING(150) NOT NULL,
    effective_start_date TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
    effective_end_date TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
    is_current CHARACTER(1) NOT NULL,
    is_active CHARACTER(1) NOT NULL,
    source_system CHARACTER VARYING(30) NOT NULL,
    created_date TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT aws_oracle_ext.systimestamp(),
    updated_date TIMESTAMP(6) WITHOUT TIME ZONE
)
;

CREATE TABLE common.dim_date(
    date_key INTEGER NOT NULL,
    full_date TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
    day_of_week CHARACTER VARYING(10) NOT NULL,
    day_of_month INTEGER NOT NULL,
    month_number INTEGER NOT NULL,
    month_name CHARACTER VARYING(15) NOT NULL,
    quarter_number INTEGER NOT NULL,
    calendar_year INTEGER NOT NULL,
    fiscal_month INTEGER NOT NULL,
    fiscal_quarter INTEGER NOT NULL,
    fiscal_year INTEGER NOT NULL,
    is_weekend CHARACTER(1) NOT NULL,
    is_holiday CHARACTER(1) NOT NULL
)
;

CREATE TABLE common.dim_geography(
    geography_key BIGINT NOT NULL,
    country_code CHARACTER VARYING(3) NOT NULL,
    country_name CHARACTER VARYING(100) NOT NULL,
    state_code CHARACTER VARYING(10),
    state_name CHARACTER VARYING(100),
    county_name CHARACTER VARYING(100),
    city_name CHARACTER VARYING(100),
    zip_code CHARACTER VARYING(10),
    region_name CHARACTER VARYING(50),
    source_system CHARACTER VARYING(30) NOT NULL,
    created_date TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT aws_oracle_ext.systimestamp()
)
;

CREATE TABLE common.dim_program(
    program_key BIGINT NOT NULL,
    agency_key BIGINT NOT NULL,
    program_code CHARACTER VARYING(30) NOT NULL,
    program_name CHARACTER VARYING(150) NOT NULL,
    program_category CHARACTER VARYING(50),
    effective_start_date TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
    effective_end_date TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
    is_current CHARACTER(1) NOT NULL,
    is_active CHARACTER(1) NOT NULL,
    source_system CHARACTER VARYING(30) NOT NULL,
    created_date TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT aws_oracle_ext.systimestamp(),
    updated_date TIMESTAMP(6) WITHOUT TIME ZONE
)
;

CREATE TABLE finance.fact_budget_execution(
    budget_execution_key BIGINT NOT NULL,
    snapshot_id CHARACTER VARYING(40) NOT NULL,
    snapshot_date_key INTEGER NOT NULL,
    agency_key BIGINT NOT NULL,
    program_key BIGINT NOT NULL,
    fiscal_year INTEGER NOT NULL,
    accounting_period INTEGER NOT NULL,
    fund_code CHARACTER VARYING(30) NOT NULL,
    original_budget NUMERIC(16,2) NOT NULL,
    current_budget NUMERIC(16,2) NOT NULL,
    budget_adjustments NUMERIC(16,2) NOT NULL DEFAULT 0,
    total_obligations NUMERIC(16,2) NOT NULL DEFAULT 0,
    unobligated_balance NUMERIC(16,2) NOT NULL DEFAULT 0,
    total_expenditures NUMERIC(16,2) NOT NULL DEFAULT 0,
    total_disbursements NUMERIC(16,2) NOT NULL DEFAULT 0,
    remaining_budget NUMERIC(16,2) NOT NULL DEFAULT 0,
    commitment_percentage DOUBLE PRECISION,
    execution_percentage DOUBLE PRECISION,
    source_system CHARACTER VARYING(30) NOT NULL,
    created_timestamp TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT aws_oracle_ext.systimestamp()
)
;

CREATE TABLE finance.fact_financial_transaction(
    transaction_key BIGINT NOT NULL,
    transaction_id CHARACTER VARYING(40) NOT NULL,
    source_transaction_id CHARACTER VARYING(50),
    transaction_date_key INTEGER NOT NULL,
    agency_key BIGINT NOT NULL,
    program_key BIGINT NOT NULL,
    geography_key BIGINT,
    fiscal_year INTEGER NOT NULL,
    accounting_period INTEGER NOT NULL,
    fund_code CHARACTER VARYING(30) NOT NULL,
    appropriation_code CHARACTER VARYING(40),
    transaction_type CHARACTER VARYING(30) NOT NULL,
    transaction_category CHARACTER VARYING(40),
    transaction_description CHARACTER VARYING(250),
    transaction_status CHARACTER VARYING(30) NOT NULL,
    original_amount NUMERIC(16,2) NOT NULL DEFAULT 0,
    revised_amount NUMERIC(16,2) NOT NULL DEFAULT 0,
    obligated_amount NUMERIC(16,2) NOT NULL DEFAULT 0,
    expended_amount NUMERIC(16,2) NOT NULL DEFAULT 0,
    paid_amount NUMERIC(16,2) NOT NULL DEFAULT 0,
    source_system CHARACTER VARYING(30) NOT NULL,
    created_timestamp TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT aws_oracle_ext.systimestamp(),
    last_updated_timestamp TIMESTAMP(6) WITHOUT TIME ZONE
)
;

CREATE TABLE grants.dim_recipient(
    recipient_key BIGINT NOT NULL,
    recipient_id CHARACTER VARYING(30) NOT NULL,
    recipient_name CHARACTER VARYING(200) NOT NULL,
    recipient_type CHARACTER VARYING(50) NOT NULL,
    tax_identifier CHARACTER VARYING(20),
    state_code CHARACTER VARYING(10),
    city CHARACTER VARYING(100),
    country_code CHARACTER VARYING(3) NOT NULL,
    certification_status CHARACTER VARYING(30),
    effective_start_date TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
    effective_end_date TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
    current_flag CHARACTER(1) NOT NULL,
    created_date TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT aws_oracle_ext.systimestamp(),
    updated_date TIMESTAMP(6) WITHOUT TIME ZONE
)
;

CREATE TABLE grants.fact_grant_application(
    application_key BIGINT NOT NULL,
    application_id CHARACTER VARYING(30) NOT NULL,
    submission_date_key INTEGER NOT NULL,
    agency_key BIGINT NOT NULL,
    program_key BIGINT NOT NULL,
    recipient_key BIGINT NOT NULL,
    geography_key BIGINT,
    application_status CHARACTER VARYING(30) NOT NULL,
    requested_amount NUMERIC(15,2) NOT NULL,
    approved_amount NUMERIC(15,2),
    disbursed_amount NUMERIC(15,2),
    created_timestamp TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT aws_oracle_ext.systimestamp(),
    last_updated_timestamp TIMESTAMP(6) WITHOUT TIME ZONE
)
;

CREATE TABLE procurement.dim_contract(
    contract_key BIGINT NOT NULL,
    contract_id CHARACTER VARYING(40) NOT NULL,
    award_id CHARACTER VARYING(40),
    vendor_key BIGINT NOT NULL,
    contract_type CHARACTER VARYING(40) NOT NULL,
    award_method CHARACTER VARYING(40),
    contract_description CHARACTER VARYING(250),
    award_amount NUMERIC(16,2) NOT NULL,
    contract_ceiling_amount NUMERIC(16,2),
    award_date TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
    performance_start_date TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
    performance_end_date TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
    contract_status CHARACTER VARYING(30) NOT NULL,
    effective_start_date TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
    effective_end_date TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
    current_flag CHARACTER(1) NOT NULL DEFAULT 'Y',
    created_timestamp TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT aws_oracle_ext.systimestamp(),
    updated_timestamp TIMESTAMP(6) WITHOUT TIME ZONE
)
;

CREATE TABLE procurement.dim_vendor(
    vendor_key BIGINT NOT NULL,
    vendor_id CHARACTER VARYING(30) NOT NULL,
    vendor_name CHARACTER VARYING(200) NOT NULL,
    vendor_type CHARACTER VARYING(40) NOT NULL,
    business_category CHARACTER VARYING(60),
    certification_status CHARACTER VARYING(30),
    state_code CHARACTER VARYING(10),
    country_code CHARACTER VARYING(3) NOT NULL DEFAULT 'USA',
    effective_start_date TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
    effective_end_date TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
    current_flag CHARACTER(1) NOT NULL DEFAULT 'Y',
    created_timestamp TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT aws_oracle_ext.systimestamp(),
    updated_timestamp TIMESTAMP(6) WITHOUT TIME ZONE
)
;

CREATE TABLE procurement.fact_contract_payment(
    payment_key BIGINT NOT NULL,
    payment_id CHARACTER VARYING(40) NOT NULL,
    invoice_id CHARACTER VARYING(40) NOT NULL,
    purchase_order_line_key BIGINT NOT NULL,
    contract_key BIGINT NOT NULL,
    vendor_key BIGINT NOT NULL,
    invoice_date_key INTEGER NOT NULL,
    due_date_key INTEGER NOT NULL,
    payment_date_key INTEGER,
    agency_key BIGINT NOT NULL,
    program_key BIGINT NOT NULL,
    fiscal_year INTEGER NOT NULL,
    accounting_period INTEGER NOT NULL,
    gross_invoice_amount NUMERIC(16,2) NOT NULL,
    discount_amount NUMERIC(16,2) NOT NULL DEFAULT 0,
    retainage_amount NUMERIC(16,2) NOT NULL DEFAULT 0,
    adjustment_amount NUMERIC(16,2) NOT NULL DEFAULT 0,
    net_payment_amount NUMERIC(16,2) NOT NULL,
    payment_status CHARACTER VARYING(30) NOT NULL,
    payment_method CHARACTER VARYING(30),
    source_system CHARACTER VARYING(30) NOT NULL,
    created_timestamp TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT aws_oracle_ext.systimestamp()
)
;

CREATE TABLE procurement.fact_purchase_order(
    purchase_order_line_key BIGINT NOT NULL,
    purchase_order_id CHARACTER VARYING(40) NOT NULL,
    line_number INTEGER NOT NULL,
    contract_key BIGINT NOT NULL,
    order_date_key INTEGER NOT NULL,
    delivery_date_key INTEGER NOT NULL,
    agency_key BIGINT NOT NULL,
    program_key BIGINT NOT NULL,
    geography_key BIGINT,
    fiscal_year INTEGER NOT NULL,
    accounting_period INTEGER NOT NULL,
    item_category CHARACTER VARYING(50) NOT NULL,
    item_description CHARACTER VARYING(250),
    quantity DOUBLE PRECISION NOT NULL,
    unit_of_measure CHARACTER VARYING(20),
    unit_price NUMERIC(16,2) NOT NULL,
    line_amount NUMERIC(16,2) NOT NULL,
    obligated_amount NUMERIC(16,2) NOT NULL,
    received_amount NUMERIC(16,2) NOT NULL DEFAULT 0,
    paid_amount NUMERIC(16,2) NOT NULL DEFAULT 0,
    order_status CHARACTER VARYING(30) NOT NULL,
    source_system CHARACTER VARYING(30) NOT NULL,
    created_timestamp TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT aws_oracle_ext.systimestamp(),
    last_updated_timestamp TIMESTAMP(6) WITHOUT TIME ZONE
)
;

-- ------------ Write CREATE-INDEX-stage scripts -----------

CREATE UNIQUE INDEX ux_dim_agency_current
ON common.dim_agency
USING BTREE ((CASE
    WHEN is_current = 'Y' THEN department_code
END) ASC);

CREATE UNIQUE INDEX ux_dim_program_current
ON common.dim_program
USING BTREE ((CASE
    WHEN is_current = 'Y' THEN program_code
END) ASC);

CREATE UNIQUE INDEX ux_dim_recipient_current
ON grants.dim_recipient
USING BTREE ((CASE
    WHEN current_flag = 'Y' THEN recipient_id
END) ASC);

CREATE UNIQUE INDEX ux_dim_contract_current
ON procurement.dim_contract
USING BTREE ((CASE
    WHEN current_flag = 'Y' THEN contract_id
END) ASC);

CREATE UNIQUE INDEX ux_dim_vendor_current
ON procurement.dim_vendor
USING BTREE ((CASE
    WHEN current_flag = 'Y' THEN vendor_id
END) ASC);

-- ------------ Write CREATE-CONSTRAINT-stage scripts -----------

ALTER TABLE common.dim_agency
ADD CONSTRAINT ck_dim_agency_active CHECK (is_active IN ('Y', 'N'));

ALTER TABLE common.dim_agency
ADD CONSTRAINT ck_dim_agency_current CHECK (is_current IN ('Y', 'N'));

ALTER TABLE common.dim_agency
ADD CONSTRAINT ck_dim_agency_dates CHECK (effective_end_date >= effective_start_date);

ALTER TABLE common.dim_agency
ADD CONSTRAINT pk_dim_agency PRIMARY KEY (agency_key);

ALTER TABLE common.dim_agency
ADD CONSTRAINT uk_dim_agency_version UNIQUE (department_code, effective_start_date);

ALTER TABLE common.dim_date
ADD CONSTRAINT ck_dim_date_fiscal_month CHECK (fiscal_month BETWEEN 1 AND 12);

ALTER TABLE common.dim_date
ADD CONSTRAINT ck_dim_date_fiscal_quarter CHECK (fiscal_quarter BETWEEN 1 AND 4);

ALTER TABLE common.dim_date
ADD CONSTRAINT ck_dim_date_holiday CHECK (is_holiday IN ('Y', 'N'));

ALTER TABLE common.dim_date
ADD CONSTRAINT ck_dim_date_month CHECK (month_number BETWEEN 1 AND 12);

ALTER TABLE common.dim_date
ADD CONSTRAINT ck_dim_date_quarter CHECK (quarter_number BETWEEN 1 AND 4);

ALTER TABLE common.dim_date
ADD CONSTRAINT ck_dim_date_weekend CHECK (is_weekend IN ('Y', 'N'));

ALTER TABLE common.dim_date
ADD CONSTRAINT pk_dim_date PRIMARY KEY (date_key);

ALTER TABLE common.dim_date
ADD CONSTRAINT uk_dim_date_full_date UNIQUE (full_date);

ALTER TABLE common.dim_geography
ADD CONSTRAINT pk_dim_geography PRIMARY KEY (geography_key);

ALTER TABLE common.dim_geography
ADD CONSTRAINT uk_dim_geography_location UNIQUE (country_code, state_code, county_name, city_name, zip_code);

ALTER TABLE common.dim_program
ADD CONSTRAINT ck_dim_program_active CHECK (is_active IN ('Y', 'N'));

ALTER TABLE common.dim_program
ADD CONSTRAINT ck_dim_program_current CHECK (is_current IN ('Y', 'N'));

ALTER TABLE common.dim_program
ADD CONSTRAINT ck_dim_program_dates CHECK (effective_end_date >= effective_start_date);

ALTER TABLE common.dim_program
ADD CONSTRAINT pk_dim_program PRIMARY KEY (program_key);

ALTER TABLE common.dim_program
ADD CONSTRAINT uk_dim_program_version UNIQUE (program_code, effective_start_date);

ALTER TABLE finance.fact_budget_execution
ADD CONSTRAINT ck_budget_amounts CHECK (original_budget >= 0 AND current_budget >= 0 AND total_obligations >= 0 AND total_expenditures >= 0 AND total_disbursements >= 0 AND remaining_budget >= 0);

ALTER TABLE finance.fact_budget_execution
ADD CONSTRAINT ck_budget_disbursements CHECK (total_disbursements <= total_expenditures);

ALTER TABLE finance.fact_budget_execution
ADD CONSTRAINT ck_budget_execution CHECK (execution_percentage BETWEEN 0 AND 100);

ALTER TABLE finance.fact_budget_execution
ADD CONSTRAINT ck_budget_period CHECK (accounting_period BETWEEN 1 AND 12);

ALTER TABLE finance.fact_budget_execution
ADD CONSTRAINT pk_fact_budget_execution PRIMARY KEY (budget_execution_key);

ALTER TABLE finance.fact_budget_execution
ADD CONSTRAINT uk_fact_budget_execution UNIQUE (snapshot_id);

ALTER TABLE finance.fact_financial_transaction
ADD CONSTRAINT ck_fin_trans_amounts CHECK (original_amount >= 0 AND revised_amount >= 0 AND obligated_amount >= 0 AND expended_amount >= 0 AND paid_amount >= 0);

ALTER TABLE finance.fact_financial_transaction
ADD CONSTRAINT ck_fin_trans_expended CHECK (expended_amount <= obligated_amount);

ALTER TABLE finance.fact_financial_transaction
ADD CONSTRAINT ck_fin_trans_paid CHECK (paid_amount <= expended_amount);

ALTER TABLE finance.fact_financial_transaction
ADD CONSTRAINT ck_fin_trans_period CHECK (accounting_period BETWEEN 1 AND 12);

ALTER TABLE finance.fact_financial_transaction
ADD CONSTRAINT pk_fact_financial_transaction PRIMARY KEY (transaction_key);

ALTER TABLE finance.fact_financial_transaction
ADD CONSTRAINT uk_fact_financial_transaction UNIQUE (transaction_id);

ALTER TABLE grants.dim_recipient
ADD CONSTRAINT ck_dim_recipient_current CHECK (current_flag IN ('Y', 'N'));

ALTER TABLE grants.dim_recipient
ADD CONSTRAINT ck_dim_recipient_dates CHECK (effective_end_date >= effective_start_date);

ALTER TABLE grants.dim_recipient
ADD CONSTRAINT pk_dim_recipient PRIMARY KEY (recipient_key);

ALTER TABLE grants.dim_recipient
ADD CONSTRAINT uk_dim_recipient_version UNIQUE (recipient_id, effective_start_date);

ALTER TABLE grants.fact_grant_application
ADD CONSTRAINT ck_grant_app_approved CHECK (approved_amount IS NULL OR approved_amount >= 0);

ALTER TABLE grants.fact_grant_application
ADD CONSTRAINT ck_grant_app_disbursed CHECK (disbursed_amount IS NULL OR disbursed_amount >= 0);

ALTER TABLE grants.fact_grant_application
ADD CONSTRAINT ck_grant_app_requested CHECK (requested_amount >= 0);

ALTER TABLE grants.fact_grant_application
ADD CONSTRAINT pk_fact_grant_application PRIMARY KEY (application_key);

ALTER TABLE grants.fact_grant_application
ADD CONSTRAINT uk_fact_grant_application UNIQUE (application_id);

ALTER TABLE procurement.dim_contract
ADD CONSTRAINT ck_dim_contract_amounts CHECK (award_amount >= 0 AND (contract_ceiling_amount IS NULL OR contract_ceiling_amount >= award_amount));

ALTER TABLE procurement.dim_contract
ADD CONSTRAINT ck_dim_contract_current CHECK (current_flag IN ('Y', 'N'));

ALTER TABLE procurement.dim_contract
ADD CONSTRAINT ck_dim_contract_dates CHECK (performance_end_date >= performance_start_date AND effective_end_date >= effective_start_date);

ALTER TABLE procurement.dim_contract
ADD CONSTRAINT pk_dim_contract PRIMARY KEY (contract_key);

ALTER TABLE procurement.dim_contract
ADD CONSTRAINT uk_dim_contract_version UNIQUE (contract_id, effective_start_date);

ALTER TABLE procurement.dim_vendor
ADD CONSTRAINT ck_dim_vendor_current CHECK (current_flag IN ('Y', 'N'));

ALTER TABLE procurement.dim_vendor
ADD CONSTRAINT ck_dim_vendor_dates CHECK (effective_end_date >= effective_start_date);

ALTER TABLE procurement.dim_vendor
ADD CONSTRAINT pk_dim_vendor PRIMARY KEY (vendor_key);

ALTER TABLE procurement.dim_vendor
ADD CONSTRAINT uk_dim_vendor_version UNIQUE (vendor_id, effective_start_date);

ALTER TABLE procurement.fact_contract_payment
ADD CONSTRAINT ck_cp_amounts CHECK (gross_invoice_amount >= 0 AND discount_amount >= 0 AND retainage_amount >= 0 AND net_payment_amount >= 0);

ALTER TABLE procurement.fact_contract_payment
ADD CONSTRAINT ck_cp_payment CHECK (net_payment_amount = gross_invoice_amount - discount_amount - retainage_amount + adjustment_amount);

ALTER TABLE procurement.fact_contract_payment
ADD CONSTRAINT ck_cp_period CHECK (accounting_period BETWEEN 1 AND 12);

ALTER TABLE procurement.fact_contract_payment
ADD CONSTRAINT pk_fact_contract_payment PRIMARY KEY (payment_key);

ALTER TABLE procurement.fact_contract_payment
ADD CONSTRAINT uk_fact_contract_payment UNIQUE (payment_id);

ALTER TABLE procurement.fact_purchase_order
ADD CONSTRAINT ck_po_amounts CHECK (unit_price >= 0 AND line_amount >= 0 AND obligated_amount >= 0 AND received_amount >= 0 AND paid_amount >= 0);

ALTER TABLE procurement.fact_purchase_order
ADD CONSTRAINT ck_po_paid CHECK (paid_amount <= received_amount);

ALTER TABLE procurement.fact_purchase_order
ADD CONSTRAINT ck_po_period CHECK (accounting_period BETWEEN 1 AND 12);

ALTER TABLE procurement.fact_purchase_order
ADD CONSTRAINT ck_po_quantity CHECK (quantity > 0);

ALTER TABLE procurement.fact_purchase_order
ADD CONSTRAINT ck_po_received CHECK (received_amount <= line_amount);

ALTER TABLE procurement.fact_purchase_order
ADD CONSTRAINT pk_fact_purchase_order PRIMARY KEY (purchase_order_line_key);

ALTER TABLE procurement.fact_purchase_order
ADD CONSTRAINT uk_fact_purchase_order UNIQUE (purchase_order_id, line_number);

-- ------------ Write CREATE-FOREIGN-KEY-CONSTRAINT-stage scripts -----------

ALTER TABLE common.dim_program
ADD CONSTRAINT fk_dim_program_agency FOREIGN KEY (agency_key) 
REFERENCES common.dim_agency (agency_key)
ON DELETE NO ACTION;

ALTER TABLE finance.fact_budget_execution
ADD CONSTRAINT fk_budget_agency FOREIGN KEY (agency_key) 
REFERENCES common.dim_agency (agency_key)
ON DELETE NO ACTION;

ALTER TABLE finance.fact_budget_execution
ADD CONSTRAINT fk_budget_program FOREIGN KEY (program_key) 
REFERENCES common.dim_program (program_key)
ON DELETE NO ACTION;

ALTER TABLE finance.fact_budget_execution
ADD CONSTRAINT fk_budget_snapshot_date FOREIGN KEY (snapshot_date_key) 
REFERENCES common.dim_date (date_key)
ON DELETE NO ACTION;

ALTER TABLE finance.fact_financial_transaction
ADD CONSTRAINT fk_fin_trans_agency FOREIGN KEY (agency_key) 
REFERENCES common.dim_agency (agency_key)
ON DELETE NO ACTION;

ALTER TABLE finance.fact_financial_transaction
ADD CONSTRAINT fk_fin_trans_date FOREIGN KEY (transaction_date_key) 
REFERENCES common.dim_date (date_key)
ON DELETE NO ACTION;

ALTER TABLE finance.fact_financial_transaction
ADD CONSTRAINT fk_fin_trans_geography FOREIGN KEY (geography_key) 
REFERENCES common.dim_geography (geography_key)
ON DELETE NO ACTION;

ALTER TABLE finance.fact_financial_transaction
ADD CONSTRAINT fk_fin_trans_program FOREIGN KEY (program_key) 
REFERENCES common.dim_program (program_key)
ON DELETE NO ACTION;

ALTER TABLE grants.fact_grant_application
ADD CONSTRAINT fk_grant_app_agency FOREIGN KEY (agency_key) 
REFERENCES common.dim_agency (agency_key)
ON DELETE NO ACTION;

ALTER TABLE grants.fact_grant_application
ADD CONSTRAINT fk_grant_app_date FOREIGN KEY (submission_date_key) 
REFERENCES common.dim_date (date_key)
ON DELETE NO ACTION;

ALTER TABLE grants.fact_grant_application
ADD CONSTRAINT fk_grant_app_geography FOREIGN KEY (geography_key) 
REFERENCES common.dim_geography (geography_key)
ON DELETE NO ACTION;

ALTER TABLE grants.fact_grant_application
ADD CONSTRAINT fk_grant_app_program FOREIGN KEY (program_key) 
REFERENCES common.dim_program (program_key)
ON DELETE NO ACTION;

ALTER TABLE grants.fact_grant_application
ADD CONSTRAINT fk_grant_app_recipient FOREIGN KEY (recipient_key) 
REFERENCES grants.dim_recipient (recipient_key)
ON DELETE NO ACTION;

ALTER TABLE procurement.dim_contract
ADD CONSTRAINT fk_dim_contract_vendor FOREIGN KEY (vendor_key) 
REFERENCES procurement.dim_vendor (vendor_key)
ON DELETE NO ACTION;

ALTER TABLE procurement.fact_contract_payment
ADD CONSTRAINT fk_cp_agency FOREIGN KEY (agency_key) 
REFERENCES common.dim_agency (agency_key)
ON DELETE NO ACTION;

ALTER TABLE procurement.fact_contract_payment
ADD CONSTRAINT fk_cp_contract FOREIGN KEY (contract_key) 
REFERENCES procurement.dim_contract (contract_key)
ON DELETE NO ACTION;

ALTER TABLE procurement.fact_contract_payment
ADD CONSTRAINT fk_cp_due_date FOREIGN KEY (due_date_key) 
REFERENCES common.dim_date (date_key)
ON DELETE NO ACTION;

ALTER TABLE procurement.fact_contract_payment
ADD CONSTRAINT fk_cp_invoice_date FOREIGN KEY (invoice_date_key) 
REFERENCES common.dim_date (date_key)
ON DELETE NO ACTION;

ALTER TABLE procurement.fact_contract_payment
ADD CONSTRAINT fk_cp_payment_date FOREIGN KEY (payment_date_key) 
REFERENCES common.dim_date (date_key)
ON DELETE NO ACTION;

ALTER TABLE procurement.fact_contract_payment
ADD CONSTRAINT fk_cp_program FOREIGN KEY (program_key) 
REFERENCES common.dim_program (program_key)
ON DELETE NO ACTION;

ALTER TABLE procurement.fact_contract_payment
ADD CONSTRAINT fk_cp_purchase_order FOREIGN KEY (purchase_order_line_key) 
REFERENCES procurement.fact_purchase_order (purchase_order_line_key)
ON DELETE NO ACTION;

ALTER TABLE procurement.fact_contract_payment
ADD CONSTRAINT fk_cp_vendor FOREIGN KEY (vendor_key) 
REFERENCES procurement.dim_vendor (vendor_key)
ON DELETE NO ACTION;

ALTER TABLE procurement.fact_purchase_order
ADD CONSTRAINT fk_po_agency FOREIGN KEY (agency_key) 
REFERENCES common.dim_agency (agency_key)
ON DELETE NO ACTION;

ALTER TABLE procurement.fact_purchase_order
ADD CONSTRAINT fk_po_contract FOREIGN KEY (contract_key) 
REFERENCES procurement.dim_contract (contract_key)
ON DELETE NO ACTION;

ALTER TABLE procurement.fact_purchase_order
ADD CONSTRAINT fk_po_delivery_date FOREIGN KEY (delivery_date_key) 
REFERENCES common.dim_date (date_key)
ON DELETE NO ACTION;

ALTER TABLE procurement.fact_purchase_order
ADD CONSTRAINT fk_po_geography FOREIGN KEY (geography_key) 
REFERENCES common.dim_geography (geography_key)
ON DELETE NO ACTION;

ALTER TABLE procurement.fact_purchase_order
ADD CONSTRAINT fk_po_order_date FOREIGN KEY (order_date_key) 
REFERENCES common.dim_date (date_key)
ON DELETE NO ACTION;

ALTER TABLE procurement.fact_purchase_order
ADD CONSTRAINT fk_po_program FOREIGN KEY (program_key) 
REFERENCES common.dim_program (program_key)
ON DELETE NO ACTION;

