-- =============================================================================
-- MODULE 01 | SCHEMA EVOLUTION
-- File    : 01b_insert_customers.sql
-- Purpose : Seed realistic multifinance customer data (Snapshot #1)
--           Data represents the ORIGINAL schema (no extra columns yet).
-- =============================================================================

USE iceberg.multifinance_xyz;

INSERT INTO iceberg.multifinance_xyz.customer VALUES
-- Batch 1: January 2024 onboarding
(10001, '3171234500010001', 'Budi Santoso',        '081234567001', 'Jakarta Pusat',  'DKI Jakarta',      'MIDDLE',  TIMESTAMP '2024-01-05 08:30:00.000000', false),
(10002, '3171234500010002', 'Siti Rahma',           '081234567002', 'Jakarta Selatan','DKI Jakarta',      'PREMIUM', TIMESTAMP '2024-01-07 09:15:00.000000', false),
(10003, '3201234500010003', 'Andi Wijaya',          '081234567003', 'Bandung',        'Jawa Barat',       'MASS',    TIMESTAMP '2024-01-10 10:00:00.000000', false),
(10004, '3371234500010004', 'Dewi Kusuma',          '081234567004', 'Semarang',       'Jawa Tengah',      'MIDDLE',  TIMESTAMP '2024-01-12 11:00:00.000000', false),
(10005, '3578234500010005', 'Fajar Hidayat',        '081234567005', 'Surabaya',       'Jawa Timur',       'MASS',    TIMESTAMP '2024-01-15 08:00:00.000000', false),
(10006, '6471234500010006', 'Rini Puspita',         '081234567006', 'Balikpapan',     'Kalimantan Timur', 'MASS',    TIMESTAMP '2024-01-18 13:00:00.000000', false),
(10007, '7371234500010007', 'Hendri Saputra',       '081234567007', 'Makassar',       'Sulawesi Selatan', 'MIDDLE',  TIMESTAMP '2024-01-20 09:30:00.000000', false),
(10008, '1271234500010008', 'Nurul Aisyah',         '081234567008', 'Medan',          'Sumatera Utara',   'PREMIUM', TIMESTAMP '2024-01-22 10:45:00.000000', false),

-- Batch 2: February 2024 onboarding
(10009, '3171234500010009', 'Ahmad Fauzi',          '081234567009', 'Jakarta Barat',  'DKI Jakarta',      'MASS',    TIMESTAMP '2024-02-03 08:00:00.000000', false),
(10010, '3201234500010010', 'Lestari Putri',        '081234567010', 'Bekasi',         'Jawa Barat',       'MIDDLE',  TIMESTAMP '2024-02-05 09:00:00.000000', false),
(10011, '3201234500010011', 'Dian Permana',         '081234567011', 'Depok',          'Jawa Barat',       'MASS',    TIMESTAMP '2024-02-08 10:30:00.000000', false),
(10012, '3401234500010012', 'Wahyu Setiawan',       '081234567012', 'Yogyakarta',     'DI Yogyakarta',    'MIDDLE',  TIMESTAMP '2024-02-10 11:00:00.000000', false),
(10013, '5271234500010013', 'Ratna Dewi',           '081234567013', 'Pontianak',      'Kalimantan Barat', 'MASS',    TIMESTAMP '2024-02-12 08:30:00.000000', false),
(10014, '1471234500010014', 'Rizky Pratama',        '081234567014', 'Palembang',      'Sumatera Selatan', 'MIDDLE',  TIMESTAMP '2024-02-15 09:15:00.000000', false),
(10015, '5101234500010015', 'Yuliana Sari',         '081234567015', 'Samarinda',      'Kalimantan Timur', 'PREMIUM', TIMESTAMP '2024-02-18 10:00:00.000000', false);

-- Confirm row count and snapshot created
SELECT COUNT(*) AS total_customers FROM iceberg.multifinance_xyz.customer;

-- Inspect the snapshot just created
SELECT snapshot_id, committed_at, operation, summary
FROM iceberg.multifinance_xyz."customer$snapshots"
ORDER BY committed_at DESC
LIMIT 3;
