-- =============================================================================
-- MODULE 03 | PARTITIONING STRATEGIES
-- File    : 03a_create_disbursement.sql
-- Purpose : Create disbursement table with multi-column partition spec v2.
--
-- PARTITION SPEC EXPLAINED:
--   month(disbursement_date)   → Iceberg hidden transform: extracts YYYY-MM
--                                 Partition dir: disbursement_date_month=2024-01
--   product_type               → Identity partition: exact value match
--                                 Partition dir: product_type=MOTOR
--   bucket(branch_code, 16)    → Bucket transform: hash mod 16
--                                 Distributes data evenly, avoids small files
--                                 Good for high-cardinality columns
--
-- Iceberg stores partition metadata in the manifest files, NOT the directory
-- name — so the partition spec can evolve without rewriting data.
-- =============================================================================

USE iceberg.multifinance_xyz;

DROP TABLE IF EXISTS iceberg.multifinance_xyz.disbursement;

CREATE TABLE iceberg.multifinance_xyz.disbursement (
    disbursement_id     bigint          COMMENT 'Surrogate PK',
    application_id      bigint          COMMENT 'FK → loan_application',
    customer_id         bigint          COMMENT 'FK → customer (denormalized)',
    disbursement_date   date            COMMENT 'Date funds were transferred',
    disbursed_amount    decimal(18,2)   COMMENT 'Actual principal disbursed in IDR',
    product_type        varchar(50)     COMMENT 'MOTOR | MOBIL | ALAT_BERAT | MULTIGUNA',
    branch_code         varchar(10)     COMMENT 'Disbursing branch code',
    bank_name           varchar(100)    COMMENT 'Destination bank',
    bank_account_no     varchar(30)     COMMENT 'Customer bank account number',
    va_number           varchar(30)     COMMENT 'Virtual account for repayment',
    first_due_date      date            COMMENT 'First installment due date',
    maturity_date       date            COMMENT 'Final installment due date',
    outstanding_principal decimal(18,2) COMMENT 'Current outstanding principal',
    loan_status         varchar(30)     COMMENT 'ACTIVE | CLOSED | NPL | RESTRUCTURED',
    created_at          timestamp(6),
    updated_at          timestamp(6)
)
WITH (
    format          = 'PARQUET',
    format_version  = 2,
    partitioning    = ARRAY[
        'month(disbursement_date)',
        'product_type',
        'bucket(branch_code, 16)'
    ]
);

SHOW CREATE TABLE iceberg.multifinance_xyz.disbursement;
