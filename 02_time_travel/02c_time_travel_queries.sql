-- =============================================================================
-- MODULE 02 | TIME TRAVEL
-- File    : 02c_time_travel_queries.sql
-- Purpose : Query historical snapshots using:
--             1. FOR VERSION AS OF <snapshot_id>
--             2. FOR TIMESTAMP AS OF <timestamp>
--           Plus snapshot comparison and audit use cases.
--
-- BUSINESS VALUE:
--   - Regulatory audit: reconstruct portfolio state at any past date
--   - Debugging: see data before/after a bad ETL run
--   - Incremental processing: read only records added since last snapshot
-- =============================================================================

USE iceberg.multifinance_xyz;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 1: List all snapshots — note down snapshot_ids for use below
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    snapshot_id,
    committed_at,
    operation,
    json_extract_scalar(summary, '$.total-records') AS total_records
FROM iceberg.multifinance_xyz."$snapshots"
ORDER BY committed_at;


-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 2: TIME TRAVEL — by snapshot version
-- Replace <SNAPSHOT_1_ID> with the actual snapshot_id from STEP 1.
-- After Snapshot 1: only January applications exist, all status=SUBMITTED
-- ─────────────────────────────────────────────────────────────────────────────
-- Pattern: SELECT ... FROM table FOR VERSION AS OF <snapshot_id>

SELECT application_id, customer_id, product_type, loan_amount, status
FROM iceberg.multifinance_xyz.loan_application
    FOR VERSION AS OF <SNAPSHOT_1_ID>
ORDER BY application_id;
-- Expected: 10 rows, all SUBMITTED, only Jan 2024


-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 3: TIME TRAVEL — by timestamp
-- Query the state of the table at the end of February 2024.
-- Replace the timestamp with a real time between your Snapshot 2 and 3.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT application_id, customer_id, status, application_date
FROM iceberg.multifinance_xyz.loan_application
    FOR TIMESTAMP AS OF TIMESTAMP '2024-02-29 23:59:59.000000'
ORDER BY application_date, application_id;
-- Expected: Jan + Feb applications, Jan rows already SURVEYED, Feb still SUBMITTED


-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 4: Compare two snapshots — which rows changed?
-- Classic: current state vs. Snapshot 1 (before any UPDATEs)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    curr.application_id,
    hist.status AS status_then,
    curr.status AS status_now,
    hist.survey_date,
    curr.approval_date
FROM iceberg.multifinance_xyz.loan_application AS curr
JOIN (
    SELECT application_id, status, survey_date
    FROM iceberg.multifinance_xyz.loan_application
        FOR VERSION AS OF <SNAPSHOT_1_ID>
) AS hist ON curr.application_id = hist.application_id
WHERE curr.status <> hist.status
ORDER BY curr.application_id;


-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 5: Incremental read — records added since last snapshot
-- Useful for streaming/batch pipelines that need "new records only"
-- ─────────────────────────────────────────────────────────────────────────────
-- Current total
SELECT COUNT(*) AS current_total FROM iceberg.multifinance_xyz.loan_application;

-- Total at Snapshot 2 (before March data)
SELECT COUNT(*) AS total_at_snapshot2
FROM iceberg.multifinance_xyz.loan_application
    FOR VERSION AS OF <SNAPSHOT_2_ID>;

-- Net new rows since Snapshot 2
SELECT curr.application_id, curr.application_date, curr.product_type, curr.loan_amount
FROM iceberg.multifinance_xyz.loan_application AS curr
LEFT JOIN (
    SELECT application_id
    FROM iceberg.multifinance_xyz.loan_application
        FOR VERSION AS OF <SNAPSHOT_2_ID>
) AS prev ON curr.application_id = prev.application_id
WHERE prev.application_id IS NULL
ORDER BY curr.application_id;


-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 6: Audit use case — portfolio status at specific regulatory date
-- E.g., OJK reporting: portfolio as of 31 March 2024 midnight
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    product_type,
    status,
    COUNT(*)                    AS total_applications,
    SUM(loan_amount)            AS total_principal_idr,
    AVG(loan_amount)            AS avg_principal_idr
FROM iceberg.multifinance_xyz.loan_application
    FOR TIMESTAMP AS OF TIMESTAMP '2024-03-31 23:59:59.000000'
GROUP BY product_type, status
ORDER BY product_type, status;


-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 7: History table — who changed what and when
-- $history gives a human-readable version of the snapshot log
-- ─────────────────────────────────────────────────────────────────────────────
SELECT *
FROM iceberg.multifinance_xyz."$history"
ORDER BY made_current_at;
