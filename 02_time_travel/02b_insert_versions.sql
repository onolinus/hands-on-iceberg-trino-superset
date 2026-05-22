-- =============================================================================
-- MODULE 02 | TIME TRAVEL
-- File    : 02b_insert_versions.sql
-- Purpose : Insert loan applications in 3 separate batches + run status UPDATEs.
--           Each operation creates a new Iceberg snapshot.
--           After running this script, MODULE 02c demonstrates time travel.
--
-- SNAPSHOT SEQUENCE (run in order):
--   Snapshot 1 → INSERT batch Jan 2024 (10 rows)
--   Snapshot 2 → INSERT batch Feb 2024 (10 rows)
--   Snapshot 3 → UPDATE: Jan applications move from SUBMITTED → SURVEYED
--   Snapshot 4 → INSERT batch Mar 2024 (10 rows)
--   Snapshot 5 → UPDATE: Feb applications move from SUBMITTED → APPROVED/REJECTED
-- =============================================================================

USE iceberg.multifinance_xyz;

-- ─────────────────────────────────────────────────────────────────────────────
-- SNAPSHOT 1: January 2024 applications
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO iceberg.multifinance_xyz.loan_application VALUES
(20001, 10001, 'MOTOR',      18000000.00,  24, 0.1800, DATE '2024-01-08', 'SUBMITTED', 'JKT-01', 501, NULL,           NULL,           NULL, TIMESTAMP '2024-01-08 09:00:00.000000', TIMESTAMP '2024-01-08 09:00:00.000000'),
(20002, 10002, 'MOBIL',     250000000.00,  48, 0.1400, DATE '2024-01-09', 'SUBMITTED', 'JKT-02', 502, NULL,           NULL,           NULL, TIMESTAMP '2024-01-09 10:00:00.000000', TIMESTAMP '2024-01-09 10:00:00.000000'),
(20003, 10003, 'MOTOR',      12000000.00,  18, 0.2000, DATE '2024-01-10', 'SUBMITTED', 'BDG-01', 503, NULL,           NULL,           NULL, TIMESTAMP '2024-01-10 08:30:00.000000', TIMESTAMP '2024-01-10 08:30:00.000000'),
(20004, 10004, 'MULTIGUNA',  50000000.00,  36, 0.1600, DATE '2024-01-11', 'SUBMITTED', 'SMG-01', 504, NULL,           NULL,           NULL, TIMESTAMP '2024-01-11 09:15:00.000000', TIMESTAMP '2024-01-11 09:15:00.000000'),
(20005, 10005, 'ALAT_BERAT',800000000.00,  60, 0.1200, DATE '2024-01-12', 'SUBMITTED', 'SBY-01', 505, NULL,           NULL,           NULL, TIMESTAMP '2024-01-12 07:45:00.000000', TIMESTAMP '2024-01-12 07:45:00.000000'),
(20006, 10006, 'MOTOR',      15000000.00,  24, 0.1800, DATE '2024-01-15', 'SUBMITTED', 'BPP-01', 506, NULL,           NULL,           NULL, TIMESTAMP '2024-01-15 10:00:00.000000', TIMESTAMP '2024-01-15 10:00:00.000000'),
(20007, 10007, 'MOBIL',     180000000.00,  36, 0.1500, DATE '2024-01-17', 'SUBMITTED', 'MKS-01', 507, NULL,           NULL,           NULL, TIMESTAMP '2024-01-17 11:00:00.000000', TIMESTAMP '2024-01-17 11:00:00.000000'),
(20008, 10008, 'MULTIGUNA', 100000000.00,  24, 0.1700, DATE '2024-01-19', 'SUBMITTED', 'MDN-01', 508, NULL,           NULL,           NULL, TIMESTAMP '2024-01-19 09:30:00.000000', TIMESTAMP '2024-01-19 09:30:00.000000'),
(20009, 10001, 'MULTIGUNA',  30000000.00,  12, 0.1800, DATE '2024-01-22', 'SUBMITTED', 'JKT-01', 501, NULL,           NULL,           NULL, TIMESTAMP '2024-01-22 08:00:00.000000', TIMESTAMP '2024-01-22 08:00:00.000000'),
(20010, 10003, 'MOTOR',      22000000.00,  36, 0.1800, DATE '2024-01-25', 'SUBMITTED', 'BDG-02', 503, NULL,           NULL,           NULL, TIMESTAMP '2024-01-25 10:00:00.000000', TIMESTAMP '2024-01-25 10:00:00.000000');

-- Capture Snapshot 1 ID for time travel later
SELECT 'SNAPSHOT_1' AS label, snapshot_id, committed_at
FROM iceberg.multifinance_xyz."$snapshots"
ORDER BY committed_at DESC LIMIT 1;


-- ─────────────────────────────────────────────────────────────────────────────
-- SNAPSHOT 2: February 2024 applications
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO iceberg.multifinance_xyz.loan_application VALUES
(20011, 10009,  'MOTOR',      16000000.00,  24, 0.1800, DATE '2024-02-05', 'SUBMITTED', 'JKT-03', 501, NULL, NULL, NULL, TIMESTAMP '2024-02-05 09:00:00.000000', TIMESTAMP '2024-02-05 09:00:00.000000'),
(20012, 10010,  'MOBIL',     200000000.00,  48, 0.1450, DATE '2024-02-06', 'SUBMITTED', 'BKS-01', 509, NULL, NULL, NULL, TIMESTAMP '2024-02-06 10:30:00.000000', TIMESTAMP '2024-02-06 10:30:00.000000'),
(20013, 10011,  'MOTOR',       9000000.00,  12, 0.2000, DATE '2024-02-07', 'SUBMITTED', 'DPK-01', 510, NULL, NULL, NULL, TIMESTAMP '2024-02-07 08:00:00.000000', TIMESTAMP '2024-02-07 08:00:00.000000'),
(20014, 10012,  'MULTIGUNA',  75000000.00,  36, 0.1650, DATE '2024-02-08', 'SUBMITTED', 'YGY-01', 511, NULL, NULL, NULL, TIMESTAMP '2024-02-08 09:00:00.000000', TIMESTAMP '2024-02-08 09:00:00.000000'),
(20015, 10013,  'MOTOR',      11000000.00,  18, 0.1900, DATE '2024-02-10', 'SUBMITTED', 'PTK-01', 512, NULL, NULL, NULL, TIMESTAMP '2024-02-10 10:00:00.000000', TIMESTAMP '2024-02-10 10:00:00.000000'),
(20016, 10014,  'MOBIL',     150000000.00,  36, 0.1500, DATE '2024-02-12', 'SUBMITTED', 'PLB-01', 513, NULL, NULL, NULL, TIMESTAMP '2024-02-12 09:30:00.000000', TIMESTAMP '2024-02-12 09:30:00.000000'),
(20017, 10015,  'ALAT_BERAT',600000000.00,  60, 0.1250, DATE '2024-02-14', 'SUBMITTED', 'SMR-01', 514, NULL, NULL, NULL, TIMESTAMP '2024-02-14 08:30:00.000000', TIMESTAMP '2024-02-14 08:30:00.000000'),
(20018, 10002,  'MULTIGUNA',  45000000.00,  24, 0.1700, DATE '2024-02-15', 'SUBMITTED', 'JKT-02', 502, NULL, NULL, NULL, TIMESTAMP '2024-02-15 11:00:00.000000', TIMESTAMP '2024-02-15 11:00:00.000000'),
(20019, 10007,  'MOTOR',      20000000.00,  24, 0.1800, DATE '2024-02-20', 'SUBMITTED', 'MKS-01', 507, NULL, NULL, NULL, TIMESTAMP '2024-02-20 09:00:00.000000', TIMESTAMP '2024-02-20 09:00:00.000000'),
(20020, 10008,  'MOBIL',     120000000.00,  36, 0.1500, DATE '2024-02-22', 'SUBMITTED', 'MDN-01', 508, NULL, NULL, NULL, TIMESTAMP '2024-02-22 10:00:00.000000', TIMESTAMP '2024-02-22 10:00:00.000000');

SELECT 'SNAPSHOT_2' AS label, snapshot_id, committed_at
FROM iceberg.multifinance_xyz."$snapshots"
ORDER BY committed_at DESC LIMIT 1;


-- ─────────────────────────────────────────────────────────────────────────────
-- SNAPSHOT 3: Status UPDATE — January apps move to SURVEYED
-- ─────────────────────────────────────────────────────────────────────────────
UPDATE iceberg.multifinance_xyz.loan_application
SET
    status      = 'SURVEYED',
    survey_date = application_date + INTERVAL '7' DAY,
    updated_at  = TIMESTAMP '2024-02-16 09:00:00.000000'
WHERE application_date BETWEEN DATE '2024-01-01' AND DATE '2024-01-31'
  AND status = 'SUBMITTED';

SELECT 'SNAPSHOT_3' AS label, snapshot_id, committed_at
FROM iceberg.multifinance_xyz."$snapshots"
ORDER BY committed_at DESC LIMIT 1;


-- ─────────────────────────────────────────────────────────────────────────────
-- SNAPSHOT 4: March 2024 applications
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO iceberg.multifinance_xyz.loan_application VALUES
(20021, 10004,  'MOTOR',      14000000.00,  24, 0.1800, DATE '2024-03-04', 'SUBMITTED', 'SMG-01', 504, NULL, NULL, NULL, TIMESTAMP '2024-03-04 09:00:00.000000', TIMESTAMP '2024-03-04 09:00:00.000000'),
(20022, 10005,  'MOBIL',     280000000.00,  60, 0.1350, DATE '2024-03-05', 'SUBMITTED', 'SBY-02', 505, NULL, NULL, NULL, TIMESTAMP '2024-03-05 10:00:00.000000', TIMESTAMP '2024-03-05 10:00:00.000000'),
(20023, 10006,  'MULTIGUNA',  60000000.00,  36, 0.1600, DATE '2024-03-06', 'SUBMITTED', 'BPP-01', 506, NULL, NULL, NULL, TIMESTAMP '2024-03-06 09:30:00.000000', TIMESTAMP '2024-03-06 09:30:00.000000'),
(20024, 10009,  'MOTOR',      18500000.00,  24, 0.1800, DATE '2024-03-08', 'SUBMITTED', 'JKT-03', 501, NULL, NULL, NULL, TIMESTAMP '2024-03-08 08:00:00.000000', TIMESTAMP '2024-03-08 08:00:00.000000'),
(20025, 10010,  'ALAT_BERAT',450000000.00,  48, 0.1300, DATE '2024-03-10', 'SUBMITTED', 'BKS-01', 509, NULL, NULL, NULL, TIMESTAMP '2024-03-10 10:00:00.000000', TIMESTAMP '2024-03-10 10:00:00.000000');

SELECT 'SNAPSHOT_4' AS label, snapshot_id, committed_at
FROM iceberg.multifinance_xyz."$snapshots"
ORDER BY committed_at DESC LIMIT 1;


-- ─────────────────────────────────────────────────────────────────────────────
-- SNAPSHOT 5: Approval decision on February applications
-- ─────────────────────────────────────────────────────────────────────────────
-- Approve most
UPDATE iceberg.multifinance_xyz.loan_application
SET
    status        = 'APPROVED',
    approval_date = DATE '2024-03-01',
    updated_at    = TIMESTAMP '2024-03-01 14:00:00.000000'
WHERE application_date BETWEEN DATE '2024-02-01' AND DATE '2024-02-28'
  AND application_id NOT IN (20013, 20015);  -- these two will be rejected

-- Reject 2 applications
UPDATE iceberg.multifinance_xyz.loan_application
SET
    status          = 'REJECTED',
    rejected_reason = 'DTI melebihi threshold 35% — penghasilan tidak mencukupi',
    updated_at      = TIMESTAMP '2024-03-01 14:30:00.000000'
WHERE application_id IN (20013, 20015);

SELECT 'SNAPSHOT_5' AS label, snapshot_id, committed_at
FROM iceberg.multifinance_xyz."$snapshots"
ORDER BY committed_at DESC LIMIT 1;


-- ─────────────────────────────────────────────────────────────────────────────
-- Summary: all snapshots for this table
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    snapshot_id,
    committed_at,
    operation,
    json_extract_scalar(summary, '$.added-records')     AS added,
    json_extract_scalar(summary, '$.deleted-records')   AS deleted,
    json_extract_scalar(summary, '$.total-records')     AS total
FROM iceberg.multifinance_xyz."$snapshots"
ORDER BY committed_at;
