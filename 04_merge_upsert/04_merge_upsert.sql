-- =============================================================================
-- MODULE 04 | MERGE INTO / UPSERT
-- File    : 04a_create_repayment.sql + 04b_insert + 04c_merge
-- Purpose : Demonstrate Iceberg v2 MERGE INTO (upsert + conditional delete).
--
-- ICEBERG WRITE MODES:
--   Copy-on-Write (COW) — default in Trino:
--     On UPDATE/DELETE, the entire affected data file is rewritten.
--     Best for low-frequency updates on large files.
--
--   Merge-on-Read (MOR) — set via table property write.delete.mode:
--     Writes a small "delete file" pointing to deleted row positions.
--     Original data file unchanged. Reads merge on the fly.
--     Best for high-frequency row-level updates.
--
-- This module uses COW (Trino default).
-- =============================================================================

USE iceberg.multifinance_xyz;

-- ─────────────────────────────────────────────────────────────────────────────
-- Part A: CREATE repayment_schedule table
-- ─────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS iceberg.multifinance_xyz.repayment_schedule;

CREATE TABLE iceberg.multifinance_xyz.repayment_schedule (
    schedule_id         bigint          COMMENT 'Surrogate PK',
    disbursement_id     bigint          COMMENT 'FK → disbursement',
    customer_id         bigint          COMMENT 'FK → customer (denormalized)',
    installment_no      integer         COMMENT 'Installment sequence number (1 = first)',
    due_date            date            COMMENT 'Payment due date',
    principal_due       decimal(18,2)   COMMENT 'Principal component of installment',
    interest_due        decimal(18,2)   COMMENT 'Interest component of installment',
    penalty_amount      decimal(18,2)   COMMENT 'Late payment penalty accrued',
    total_due           decimal(18,2)   COMMENT 'Total amount due this installment',
    paid_date           date            COMMENT 'Actual payment date (NULL if unpaid)',
    paid_amount         decimal(18,2)   COMMENT 'Amount paid (NULL if unpaid)',
    payment_status      varchar(20)     COMMENT 'CURRENT | OVERDUE | PAID | WAIVED',
    days_past_due       integer         COMMENT 'DPD — Days Past Due',
    collection_bucket   varchar(10)     COMMENT 'DPD bucket: CURRENT | 1-30 | 31-60 | 61-90 | 90+',
    updated_at          timestamp(6)
)
WITH (
    format          = 'PARQUET',
    format_version  = 2,
    -- write.delete.mode = 'merge-on-read' enables position delete files
    -- Uncomment below if your Trino version supports it:
    -- "write.delete.mode" = 'merge-on-read',
    -- "write.update.mode" = 'merge-on-read',
    -- "write.merge.mode"  = 'merge-on-read',
    partitioning    = ARRAY[
        'month(due_date)',
        'payment_status'
    ]
);


-- ─────────────────────────────────────────────────────────────────────────────
-- Part B: Seed initial repayment schedules (2 disbursements × 3 installments)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO iceberg.multifinance_xyz.repayment_schedule VALUES
-- Disbursement 30001 (MOTOR, 24 months, customer 10001)
(40001, 30001, 10001, 1, DATE '2024-02-18', 750000.00, 270000.00, 0.00, 1020000.00, NULL, NULL, 'CURRENT', 0, 'CURRENT',  TIMESTAMP '2024-01-18 10:00:00.000000'),
(40002, 30001, 10001, 2, DATE '2024-03-18', 750000.00, 270000.00, 0.00, 1020000.00, NULL, NULL, 'CURRENT', 0, 'CURRENT',  TIMESTAMP '2024-01-18 10:00:00.000000'),
(40003, 30001, 10001, 3, DATE '2024-04-18', 750000.00, 270000.00, 0.00, 1020000.00, NULL, NULL, 'CURRENT', 0, 'CURRENT',  TIMESTAMP '2024-01-18 10:00:00.000000'),

-- Disbursement 30008 (MOTOR, 24 months, customer 10009)
(40010, 30008, 10009, 1, DATE '2024-03-15', 666666.00, 240000.00, 0.00,  906666.00, NULL, NULL, 'CURRENT', 0, 'CURRENT',  TIMESTAMP '2024-02-15 09:00:00.000000'),
(40011, 30008, 10009, 2, DATE '2024-04-15', 666666.00, 240000.00, 0.00,  906666.00, NULL, NULL, 'CURRENT', 0, 'CURRENT',  TIMESTAMP '2024-02-15 09:00:00.000000'),
(40012, 30008, 10009, 3, DATE '2024-05-15', 666667.00, 240000.00, 0.00,  906667.00, NULL, NULL, 'CURRENT', 0, 'CURRENT',  TIMESTAMP '2024-02-15 09:00:00.000000'),

-- Disbursement 30006 (MULTIGUNA, 36 months, customer 10004)
(40020, 30006, 10004, 1, DATE '2024-02-24', 1388888.00, 66666.00, 0.00, 1455554.00, NULL, NULL, 'CURRENT', 0, 'CURRENT',  TIMESTAMP '2024-01-24 09:30:00.000000'),
(40021, 30006, 10004, 2, DATE '2024-03-24', 1388888.00, 66666.00, 0.00, 1455554.00, NULL, NULL, 'CURRENT', 0, 'CURRENT',  TIMESTAMP '2024-01-24 09:30:00.000000'),
(40022, 30006, 10004, 3, DATE '2024-04-24', 1388888.00, 66666.00, 0.00, 1455554.00, NULL, NULL, 'CURRENT', 0, 'CURRENT',  TIMESTAMP '2024-01-24 09:30:00.000000');

SELECT COUNT(*) AS initial_schedules FROM iceberg.multifinance_xyz.repayment_schedule;


-- ─────────────────────────────────────────────────────────────────────────────
-- Part C: MERGE INTO — payment processing batch
--
-- Scenario: End-of-day payment posting.
-- A staging table (repayment_incoming) contains payment events from the core
-- banking system. We MERGE these into repayment_schedule:
--   - If the schedule_id matches AND status is CURRENT → mark PAID
--   - If the schedule_id matches AND overdue → apply penalty, update DPD
--   - If no match found → the payment may be for a new installment; INSERT
-- ─────────────────────────────────────────────────────────────────────────────

-- Simulate incoming payment data (normally from Kafka / staging table)
CREATE TEMPORARY TABLE tmp_payment_events (
    schedule_id     bigint,
    paid_date       date,
    paid_amount     decimal(18,2),
    source_event    varchar(50)
);

INSERT INTO tmp_payment_events VALUES
(40001, DATE '2024-02-18', 1020000.00, 'CORE_BANKING_AUTO_DEBIT'),  -- on time
(40002, DATE '2024-03-20',  980000.00, 'TELLER_MANUAL'),            -- 2 days late, partial
(40020, DATE '2024-02-28', 1455554.00, 'VIRTUAL_ACCOUNT'),          -- on time
(40021, DATE '2024-04-05', 1455554.00, 'COLLECTION_OFFICER');       -- 12 days late


-- THE MERGE
MERGE INTO iceberg.multifinance_xyz.repayment_schedule AS target
USING tmp_payment_events AS source
ON target.schedule_id = source.schedule_id

-- WHEN MATCHED: payment received on or before due date → PAID, no penalty
WHEN MATCHED AND source.paid_date <= target.due_date THEN
    UPDATE SET
        paid_date        = source.paid_date,
        paid_amount      = source.paid_amount,
        payment_status   = 'PAID',
        days_past_due    = 0,
        collection_bucket = 'CURRENT',
        penalty_amount   = 0.00,
        updated_at       = CURRENT_TIMESTAMP

-- WHEN MATCHED: payment received LATE → update DPD, calculate penalty
WHEN MATCHED AND source.paid_date > target.due_date THEN
    UPDATE SET
        paid_date        = source.paid_date,
        paid_amount      = source.paid_amount,
        payment_status   = 'PAID',
        days_past_due    = DATE_DIFF('day', target.due_date, source.paid_date),
        collection_bucket = CASE
            WHEN DATE_DIFF('day', target.due_date, source.paid_date) BETWEEN 1  AND 30 THEN '1-30'
            WHEN DATE_DIFF('day', target.due_date, source.paid_date) BETWEEN 31 AND 60 THEN '31-60'
            WHEN DATE_DIFF('day', target.due_date, source.paid_date) BETWEEN 61 AND 90 THEN '61-90'
            ELSE '90+'
        END,
        -- Penalty: 0.1% per day of total_due
        penalty_amount   = ROUND(target.total_due * 0.001 * DATE_DIFF('day', target.due_date, source.paid_date), 0),
        updated_at       = CURRENT_TIMESTAMP;


-- Verify MERGE results
SELECT
    schedule_id,
    disbursement_id,
    installment_no,
    due_date,
    paid_date,
    payment_status,
    days_past_due,
    collection_bucket,
    penalty_amount,
    paid_amount
FROM iceberg.multifinance_xyz.repayment_schedule
WHERE schedule_id IN (40001, 40002, 40020, 40021, 40010, 40011)
ORDER BY schedule_id;
