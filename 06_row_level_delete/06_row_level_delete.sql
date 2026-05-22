-- =============================================================================
-- MODULE 06 | ROW-LEVEL DELETE
-- File    : 06_row_level_delete.sql
-- Purpose : Demonstrate row-level DELETE with predicate.
--
-- ICEBERG DELETE MECHANICS (Format v2):
--   Position Delete File: records <file_path, row_position> of deleted rows.
--     → Original data file unchanged.
--     → Read merges original + delete file on the fly.
--     → No data rewrite until you run OPTIMIZE / rewrite_data_files.
--
--   Equality Delete File: records column values that identify deleted rows.
--     → More flexible than position deletes.
--     → Used by streaming engines (Flink).
--
-- Trino uses Copy-on-Write by default: DELETE rewrites the affected data files.
-- To get position deletes, enable write.delete.mode = 'merge-on-read' in table props.
--
-- BUSINESS CASE:
--   blacklist table — customers flagged by risk/compliance team.
--   When a customer is cleared, we DELETE their blacklist entry.
--   When a batch of entries expires, we DELETE by date range.
-- =============================================================================

USE iceberg.multifinance_xyz;

-- ─────────────────────────────────────────────────────────────────────────────
-- PART A: Create blacklist table
-- ─────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS iceberg.multifinance_xyz.blacklist;

CREATE TABLE iceberg.multifinance_xyz.blacklist (
    blacklist_id        bigint          COMMENT 'Surrogate PK',
    customer_id         bigint          COMMENT 'FK → customer',
    nik                 varchar(16)     COMMENT 'NIK (denormalized for lookup without join)',
    full_name           varchar(255)    COMMENT 'Name at time of blacklisting',
    blacklist_reason    varchar(100)    COMMENT 'NPL | FRAUD | SLIK_SCORE | COLLECTION_D3 | DECEASED | SANCTION',
    blacklist_date      date            COMMENT 'Date blacklisted',
    expiry_date         date            COMMENT 'Date blacklist expires (NULL = permanent)',
    source_system       varchar(50)     COMMENT 'OJK_SLIK | INTERNAL | OJKDPK | INTERPOL',
    is_active           boolean         COMMENT 'True while still blacklisted',
    cleared_date        date            COMMENT 'Date record was cleared (NULL if still active)',
    cleared_by          varchar(100)    COMMENT 'User/system that cleared the entry',
    notes               varchar(1000)   COMMENT 'Free-text notes',
    created_at          timestamp(6),
    updated_at          timestamp(6)
)
WITH (
    format          = 'PARQUET',
    format_version  = 2,
    partitioning    = ARRAY['year(blacklist_date)', 'blacklist_reason'],
    location        = 'oss://xyz-iceberg.ap-southeast-5.oss-dls.aliyuncs.com/warehouse/multifinance_xyz/blacklist'
);


-- ─────────────────────────────────────────────────────────────────────────────
-- PART B: Seed blacklist entries
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO iceberg.multifinance_xyz.blacklist VALUES
(60001, 10005, '3578234500010005', 'Fajar Hidayat',   'NPL',           DATE '2022-06-01', NULL,           'INTERNAL',   true,  NULL, NULL, 'Angsuran macet > 6 bulan pada kontrak lama',                        TIMESTAMP '2022-06-01 09:00:00.000000', TIMESTAMP '2022-06-01 09:00:00.000000'),
(60002, 10011, '3201234500010011', 'Dian Permana',    'SLIK_SCORE',    DATE '2023-03-15', DATE '2025-03-15','OJK_SLIK',  true,  NULL, NULL, 'Skor SLIK Kol 3, sedang dalam proses restrukturisasi di bank lain',  TIMESTAMP '2023-03-15 10:00:00.000000', TIMESTAMP '2023-03-15 10:00:00.000000'),
(60003, 99901, '7112345000900001', 'Agus Supriyadi',  'FRAUD',         DATE '2023-07-20', NULL,           'INTERNAL',   true,  NULL, NULL, 'Dokumen KTP dan KK palsu ditemukan saat verifikasi survey',         TIMESTAMP '2023-07-20 08:30:00.000000', TIMESTAMP '2023-07-20 08:30:00.000000'),
(60004, 99902, '3274567890120002', 'Bambang Irawan',  'COLLECTION_D3', DATE '2023-09-01', DATE '2024-09-01','INTERNAL',  true,  NULL, NULL, 'DPD 90+ hari pada kontrak motor, unit tidak ditemukan saat lelang', TIMESTAMP '2023-09-01 11:00:00.000000', TIMESTAMP '2023-09-01 11:00:00.000000'),
(60005, 99903, '1471239087650003', 'Citra Lestari',   'SANCTION',      DATE '2023-11-10', NULL,           'OJKDPK',     true,  NULL, NULL, 'Masuk daftar terduga terorisme BNPT',                               TIMESTAMP '2023-11-10 09:00:00.000000', TIMESTAMP '2023-11-10 09:00:00.000000'),
(60006, 99904, '5271239087650004', 'Dodi Prasetyo',   'NPL',           DATE '2024-01-05', DATE '2027-01-05','INTERNAL',  true,  NULL, NULL, 'Write-off kontrak alat berat, outstanding IDR 450jt',             TIMESTAMP '2024-01-05 08:00:00.000000', TIMESTAMP '2024-01-05 08:00:00.000000'),
(60007, 99905, '6171239087650005', 'Eka Wulandari',   'SLIK_SCORE',    DATE '2024-02-14', DATE '2025-08-14','OJK_SLIK', true,  NULL, NULL, 'Kol 5 di 2 bank, proses PKPU',                                     TIMESTAMP '2024-02-14 10:00:00.000000', TIMESTAMP '2024-02-14 10:00:00.000000'),
(60008, 99906, '3172348900120006', 'Firdaus Malik',   'DECEASED',      DATE '2024-01-30', NULL,           'INTERNAL',   true,  NULL, NULL, 'Nasabah meninggal dunia, ahli waris menolak melanjutkan kewajiban', TIMESTAMP '2024-01-30 09:30:00.000000', TIMESTAMP '2024-01-30 09:30:00.000000');

SELECT COUNT(*) AS total_blacklisted FROM iceberg.multifinance_xyz.blacklist;


-- ─────────────────────────────────────────────────────────────────────────────
-- PART C: Row-level DELETE operations
-- ─────────────────────────────────────────────────────────────────────────────

-- Inspect before DELETE
SELECT blacklist_id, customer_id, nik, full_name, blacklist_reason, expiry_date, is_active
FROM iceberg.multifinance_xyz.blacklist
ORDER BY blacklist_id;


-- DELETE 1: Remove a single cleared customer by ID
-- Customer 10011 (Dian Permana) has successfully restructured their debt.
DELETE FROM iceberg.multifinance_xyz.blacklist
WHERE blacklist_id = 60002;

-- Verify: 7 rows remain
SELECT COUNT(*) AS remaining FROM iceberg.multifinance_xyz.blacklist;


-- DELETE 2: Remove all entries from SLIK_SCORE reason that have expired
-- Expiry before today = no longer relevant
DELETE FROM iceberg.multifinance_xyz.blacklist
WHERE blacklist_reason = 'SLIK_SCORE'
  AND expiry_date < CURRENT_DATE;

SELECT COUNT(*) AS remaining FROM iceberg.multifinance_xyz.blacklist;


-- DELETE 3: Batch delete expired COLLECTION_D3 entries
DELETE FROM iceberg.multifinance_xyz.blacklist
WHERE blacklist_reason = 'COLLECTION_D3'
  AND expiry_date <= DATE '2024-12-31';

SELECT COUNT(*) AS remaining FROM iceberg.multifinance_xyz.blacklist;


-- ─────────────────────────────────────────────────────────────────────────────
-- PART D: Time travel after DELETE — see deleted rows
-- ─────────────────────────────────────────────────────────────────────────────
-- The deleted rows are NOT gone from the old snapshots.
-- This is powerful for audit: who was blacklisted before the batch clear?

-- First, get the snapshot ID just after the initial INSERT (before any DELETE)
SELECT snapshot_id, committed_at, operation
FROM iceberg.multifinance_xyz."$snapshots"
ORDER BY committed_at;

-- Then query that snapshot to see all 8 original entries:
-- SELECT * FROM iceberg.multifinance_xyz.blacklist FOR VERSION AS OF <INSERT_SNAPSHOT_ID>;

-- Current state: only permanent/non-expired entries remain
SELECT
    blacklist_id,
    nik,
    full_name,
    blacklist_reason,
    blacklist_date,
    expiry_date,
    source_system
FROM iceberg.multifinance_xyz.blacklist
ORDER BY blacklist_date;
