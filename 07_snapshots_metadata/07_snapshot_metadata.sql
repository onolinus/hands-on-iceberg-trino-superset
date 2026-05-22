-- =============================================================================
-- MODULE 07 | SNAPSHOTS & METADATA TABLES
-- File    : 07_snapshot_metadata.sql
-- Purpose : Explore Iceberg's built-in metadata tables.
--           These are not user tables — they're system views over the
--           Iceberg metadata JSON/Avro files stored in object storage.
--
-- METADATA TABLE REFERENCE:
--   "<table>$snapshots"   → All snapshots with summary stats
--   "<table>$history"     → Human-readable snapshot history
--   "<table>$manifests"   → Manifest files (one per snapshot delta)
--   "<table>$files"       → All current data files with stats
--   "<table>$partitions"  → Partition-level stats
--   "<table>$entries"     → All manifest entries (active + deleted files)
--   "<table>$refs"        → Named references (branches/tags — Format v2)
--
-- TRINO SYNTAX: table name in double quotes with $ prefix inside the quotes
--   iceberg.multifinance_xyz."loan_application$snapshots"   ← wrong
--   iceberg.multifinance_xyz."$snapshots"                   ← correct (when USE schema is set)
--   Or fully qualified:
--   iceberg.multifinance_xyz.loan_application."$snapshots"  ← check your Trino version
-- =============================================================================

USE iceberg.multifinance_xyz;

-- ═════════════════════════════════════════════════════════════════════════════
-- SECTION 1: $snapshots — full snapshot log
-- ═════════════════════════════════════════════════════════════════════════════

-- All snapshots for loan_application
SELECT
    snapshot_id,
    parent_id,
    committed_at,
    operation,
    -- summary is map(varchar,varchar) — use element_at to safely handle missing keys
    element_at(summary, 'added-data-files')   AS added_files,
    element_at(summary, 'deleted-data-files') AS deleted_files,
    element_at(summary, 'added-records')      AS added_records,
    element_at(summary, 'deleted-records')    AS deleted_records,
    element_at(summary, 'total-data-files')   AS total_files,
    element_at(summary, 'total-records')      AS total_records,
    element_at(summary, 'total-files-size')   AS total_size_bytes,
    element_at(summary, 'engine-name')        AS engine,
    element_at(summary, 'flink.job-id')       AS flink_job_id   -- present if Flink wrote it
FROM iceberg.multifinance_xyz."$snapshots"
ORDER BY committed_at;


-- ═════════════════════════════════════════════════════════════════════════════
-- SECTION 2: $history — snapshot lineage
-- ═════════════════════════════════════════════════════════════════════════════
SELECT
    made_current_at,
    snapshot_id,
    parent_id,
    is_current_ancestor
FROM iceberg.multifinance_xyz."$history"
ORDER BY made_current_at;


-- ═════════════════════════════════════════════════════════════════════════════
-- SECTION 3: $files — current data files with column-level stats
-- Iceberg stores min/max values per column in each file's metadata.
-- Trino uses these for predicate pushdown (skipping files whose min/max
-- range doesn't overlap the query filter).
-- ═════════════════════════════════════════════════════════════════════════════
SELECT
    file_path,
    file_format,
    partition,
    record_count,
    file_size_in_bytes,
    -- column_sizes is a map: column_id → byte count
    -- lower_bounds / upper_bounds: column_id → min/max value bytes (serialized)
    cardinality(column_sizes)   AS tracked_columns,
    split_offsets
FROM iceberg.multifinance_xyz."$files"
ORDER BY partition, file_path
LIMIT 20;


-- ═════════════════════════════════════════════════════════════════════════════
-- SECTION 4: $partitions — partition-level statistics
-- ═════════════════════════════════════════════════════════════════════════════
SELECT
    partition,
    record_count,
    file_count,
    total_size,
    data
FROM iceberg.multifinance_xyz."$partitions"
ORDER BY record_count DESC;


-- ═════════════════════════════════════════════════════════════════════════════
-- SECTION 5: $manifests — manifest file stats
-- Each snapshot has 1+ manifest lists; each manifest list references manifests.
-- Manifests contain entries for data files (added/existing/deleted).
-- ═════════════════════════════════════════════════════════════════════════════
SELECT
    path,
    length,
    partition_spec_id,
    added_snapshot_id,
    added_data_files_count,
    existing_data_files_count,
    deleted_data_files_count,
    added_rows_count,
    existing_rows_count,
    deleted_rows_count
FROM iceberg.multifinance_xyz."$manifests"
ORDER BY added_snapshot_id;


-- ═════════════════════════════════════════════════════════════════════════════
-- SECTION 6: $refs — named branches and tags (Iceberg v2)
-- Format v2 allows named branches and tags on snapshots.
-- 'main' is the default branch.
-- ═════════════════════════════════════════════════════════════════════════════
SELECT *
FROM iceberg.multifinance_xyz."$refs";


-- ═════════════════════════════════════════════════════════════════════════════
-- SECTION 7: Cross-table metadata audit
-- How many total files, records, and bytes across all lab tables?
-- ═════════════════════════════════════════════════════════════════════════════
SELECT 'customer'             AS table_name, COUNT(*) AS file_count, SUM(record_count) AS records, SUM(file_size_in_bytes) AS bytes FROM iceberg.multifinance_xyz.customer."$files"
UNION ALL
SELECT 'loan_application',                   COUNT(*),               SUM(record_count),             SUM(file_size_in_bytes) FROM iceberg.multifinance_xyz.loan_application."$files"
UNION ALL
SELECT 'disbursement',                       COUNT(*),               SUM(record_count),             SUM(file_size_in_bytes) FROM iceberg.multifinance_xyz.disbursement."$files"
UNION ALL
SELECT 'repayment_schedule',                 COUNT(*),               SUM(record_count),             SUM(file_size_in_bytes) FROM iceberg.multifinance_xyz.repayment_schedule."$files"
UNION ALL
SELECT 'collateral',                         COUNT(*),               SUM(record_count),             SUM(file_size_in_bytes) FROM iceberg.multifinance_xyz.collateral."$files"
UNION ALL
SELECT 'blacklist',                          COUNT(*),               SUM(record_count),             SUM(file_size_in_bytes) FROM iceberg.multifinance_xyz.blacklist."$files"
ORDER BY bytes DESC;


-- ═════════════════════════════════════════════════════════════════════════════
-- SECTION 8: Table optimization commands
-- Run these periodically (e.g., via Airflow) to compact small files and
-- expire old snapshots.
-- ═════════════════════════════════════════════════════════════════════════════

-- Compact small files into larger ones (merge-on-read tables especially need this)
-- ALTER TABLE iceberg.multifinance_xyz.loan_application EXECUTE optimize;

-- Compact with target file size (512 MB)
-- ALTER TABLE iceberg.multifinance_xyz.loan_application
--     EXECUTE optimize(file_size_threshold => '512MB');

-- Expire snapshots older than 7 days (frees OSS storage)
-- ALTER TABLE iceberg.multifinance_xyz.loan_application
--     EXECUTE expire_snapshots(retention_threshold => '7d');

-- Remove orphaned files not referenced by any snapshot
-- ALTER TABLE iceberg.multifinance_xyz.loan_application
--     EXECUTE remove_orphan_files(retention_threshold => '7d');
