-- =============================================================================
-- MODULE 02 | TIME TRAVEL
-- File    : 02a_create_loan_application.sql
-- Purpose : Create loan_application table — central fact table in XYZ.
--           We'll insert data in multiple batches to generate multiple
--           Iceberg snapshots, then time-travel back to each one.
-- Feature : Iceberg v2 maintains a full snapshot log per table.
--           Every INSERT / UPDATE / DELETE / MERGE creates a new snapshot.
-- =============================================================================

USE iceberg.multifinance_xyz;

DROP TABLE IF EXISTS iceberg.multifinance_xyz.loan_application;

CREATE TABLE iceberg.multifinance_xyz.loan_application (
    application_id      bigint          COMMENT 'Surrogate PK',
    customer_id         bigint          COMMENT 'FK → customer.customer_id',
    product_type        varchar(50)     COMMENT 'MOTOR | MOBIL | ALAT_BERAT | MULTIGUNA',
    loan_amount         decimal(18,2)   COMMENT 'Requested principal in IDR',
    tenor_months        integer         COMMENT 'Loan tenor in months',
    interest_rate_pa    decimal(6,4)    COMMENT 'Annual interest rate e.g. 0.1800 = 18%',
    application_date    date            COMMENT 'Date application was submitted',
    status              varchar(30)     COMMENT 'SUBMITTED | SURVEYED | APPROVED | REJECTED | DISBURSED | ACTIVE | CLOSED | NPL',
    branch_code         varchar(10)     COMMENT 'Branch that processed the application',
    surveyor_id         bigint          COMMENT 'FK → employee (surveyor)',
    survey_date         date            COMMENT 'Physical survey date',
    approval_date       date            COMMENT 'Credit committee approval date',
    rejected_reason     varchar(500)    COMMENT 'Rejection reason if status=REJECTED',
    created_at          timestamp(6)    COMMENT 'Record created timestamp',
    updated_at          timestamp(6)    COMMENT 'Record last updated timestamp'
)
WITH (
    format          = 'PARQUET',
    format_version  = 2,
    partitioning    = ARRAY[
        'month(application_date)',      -- most queries filter by month/year
        'product_type',                 -- common filter in risk reports
        'bucket(customer_id, 8)'        -- bucket join optimization
    ]
);

SHOW CREATE TABLE iceberg.multifinance_xyz.loan_application;
