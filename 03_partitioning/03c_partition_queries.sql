-- =============================================================================
-- MODULE 03 | PARTITIONING STRATEGIES
-- File    : 03c_partition_queries.sql
-- Purpose : Demonstrate partition pruning — Trino skips entire partition
--           directories without scanning their files.
--
-- HOW TO VALIDATE PRUNING:
--   Run EXPLAIN ANALYZE on each query and look for:
--   "Partitions read: N of M" in the Iceberg scan node.
--   N < M means pruning happened.
-- =============================================================================

USE iceberg.multifinance_xyz;

-- ─────────────────────────────────────────────────────────────────────────────
-- INSPECT: What partitions exist in the table?
-- $partitions is an Iceberg metadata table
-- ─────────────────────────────────────────────────────────────────────────────
SELECT *
FROM iceberg.multifinance_xyz."$partitions"
ORDER BY partition;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 1: Partition pruning on month(disbursement_date)
-- Only February files are read — January and March are skipped.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    disbursement_id,
    application_id,
    disbursement_date,
    product_type,
    disbursed_amount
FROM iceberg.multifinance_xyz.disbursement
WHERE disbursement_date BETWEEN DATE '2024-02-01' AND DATE '2024-02-29'
ORDER BY disbursement_date;

-- See the query plan to confirm pruning
EXPLAIN ANALYZE
SELECT SUM(disbursed_amount) AS total_feb
FROM iceberg.multifinance_xyz.disbursement
WHERE disbursement_date BETWEEN DATE '2024-02-01' AND DATE '2024-02-29';


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 2: Pruning on product_type (identity partition)
-- Only MOTOR partition files are read.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    disbursement_id,
    disbursement_date,
    branch_code,
    disbursed_amount,
    outstanding_principal
FROM iceberg.multifinance_xyz.disbursement
WHERE product_type = 'MOTOR'
ORDER BY disbursement_date;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 3: Combined pruning — month + product_type
-- Trino intersects both partition predicates.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    disbursement_id,
    application_id,
    disbursement_date,
    disbursed_amount
FROM iceberg.multifinance_xyz.disbursement
WHERE disbursement_date BETWEEN DATE '2024-01-01' AND DATE '2024-01-31'
  AND product_type IN ('MOTOR', 'MOBIL')
ORDER BY disbursement_date;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 4: Bucket partition — bucket(branch_code, 16)
-- Bucket partitions help when joining two bucketed tables on the same key
-- → Trino can do a bucket-aware join without shuffling all data.
-- ─────────────────────────────────────────────────────────────────────────────
-- Aggregate disbursements by branch — Trino reads only the relevant bucket
SELECT
    branch_code,
    COUNT(*)                                AS total_disbursements,
    SUM(disbursed_amount)                   AS total_amount_idr,
    AVG(disbursed_amount)                   AS avg_amount_idr,
    MAX(disbursed_amount)                   AS max_amount_idr
FROM iceberg.multifinance_xyz.disbursement
GROUP BY branch_code
ORDER BY total_amount_idr DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 5: Business report — monthly portfolio summary by product
-- Uses month partition pruning for each month filter
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    DATE_FORMAT(disbursement_date, '%Y-%m')     AS disbursement_month,
    product_type,
    COUNT(*)                                    AS contracts,
    SUM(disbursed_amount)                       AS total_disbursed_idr,
    SUM(outstanding_principal)                  AS total_outstanding_idr,
    AVG(disbursed_amount)                       AS avg_contract_size
FROM iceberg.multifinance_xyz.disbursement
WHERE disbursement_date >= DATE '2024-01-01'
GROUP BY 1, 2
ORDER BY 1, 2;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 6: Files metadata — see how data is physically stored
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    file_path,
    file_format,
    partition,
    record_count,
    file_size_in_bytes,
    column_sizes
FROM iceberg.multifinance_xyz."$files"
ORDER BY partition, file_path;
