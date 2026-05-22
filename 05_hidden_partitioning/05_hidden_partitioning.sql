-- =============================================================================
-- MODULE 05 | HIDDEN PARTITIONING
-- File    : 05a_create_collateral.sql + 05b_hidden_partition_demo.sql
-- Purpose : Demonstrate Iceberg's hidden partition transforms.
--
-- HIDDEN PARTITION = a partition that is derived from a column value via a
-- transform function. The partition column itself is NOT a separate column in
-- the table — Iceberg manages it transparently.
--
-- Available transforms:
--   identity(col)          → exact value (same as Hive partitioning)
--   year(ts_col)           → year extracted from timestamp/date
--   month(ts_col)          → year-month e.g. 2024-01
--   day(ts_col)            → year-month-day
--   hour(ts_col)           → year-month-day-hour
--   bucket(col, N)         → hash(col) mod N → integer 0..N-1
--   truncate(col, W)       → col truncated to width W (strings: prefix, ints: rounded down)
--
-- KEY BENEFIT: Queries don't need to know about partitioning.
--   Hive: WHERE year_col = 2024 AND month_col = 1   ← you write partition columns
--   Iceberg: WHERE event_ts >= '2024-01-01'          ← Iceberg infers partition
-- =============================================================================

USE iceberg.multifinance_xyz;

-- ─────────────────────────────────────────────────────────────────────────────
-- Part A: CREATE collateral table
-- ─────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS iceberg.multifinance_xyz.collateral;

CREATE TABLE iceberg.multifinance_xyz.collateral (
    collateral_id       bigint          COMMENT 'Surrogate PK',
    application_id      bigint          COMMENT 'FK → loan_application',
    customer_id         bigint          COMMENT 'FK → customer',
    collateral_type     varchar(50)     COMMENT 'MOTOR | MOBIL | TRUK | ALAT_BERAT | PROPERTI',
    brand               varchar(100)    COMMENT 'Vehicle/equipment brand',
    model               varchar(200)    COMMENT 'Model name',
    manufacture_year    integer         COMMENT 'Year of manufacture',
    plate_number        varchar(20)     COMMENT 'License plate number',
    engine_number       varchar(50)     COMMENT 'Engine serial number',
    chassis_number      varchar(50)     COMMENT 'Chassis serial number',
    appraised_value     decimal(18,2)   COMMENT 'BPKB / appraisal value in IDR',
    ltv_ratio           decimal(5,4)    COMMENT 'Loan-to-Value ratio e.g. 0.8500 = 85%',
    bpkb_status         varchar(20)     COMMENT 'HELD | RELEASED | IN_PROCESS',
    survey_location     varchar(200)    COMMENT 'Location where collateral was surveyed',
    -- Note: registered_at is the single source column for hidden partitioning
    -- Users query on registered_at; Iceberg partitions by year+month automatically
    registered_at       timestamp(6)    COMMENT 'Timestamp collateral was registered in system',
    updated_at          timestamp(6)
)
WITH (
    format          = 'PARQUET',
    format_version  = 2,
    -- Hidden transforms: year + month gives time-based pruning
    -- truncate(brand, 3) groups brands by first 3 characters: 'HON','YAM','SUZ'...
    partitioning    = ARRAY[
        'year(registered_at)',
        'month(registered_at)',
        'truncate(collateral_type, 5)'
    ],
    location        = 'oss://xyz-iceberg.ap-southeast-5.oss-dls.aliyuncs.com/warehouse/multifinance_xyz/collateral'
);

SHOW CREATE TABLE iceberg.multifinance_xyz.collateral;


-- ─────────────────────────────────────────────────────────────────────────────
-- Part B: Insert collateral data
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO iceberg.multifinance_xyz.collateral VALUES
(50001, 20001, 10001, 'MOTOR',      'Honda',   'Beat ESP CBS ISS',          2022, 'B 1234 ABC', 'JBP3E1234567', 'MH1JBP310NK123456', 20000000.00, 0.9000, 'HELD',       'Jl. Kebon Sirih No. 12 Jakarta Pusat',    TIMESTAMP '2024-01-08 10:30:00.000000', TIMESTAMP '2024-01-08 10:30:00.000000'),
(50002, 20002, 10002, 'MOBIL',      'Toyota',  'Avanza 1.3 G MT',           2021, 'B 5678 DEF', 'NR3VE1234567', 'MHFMXXXX0M0123456', 215000000.00,0.8500, 'HELD',       'Jl. Sudirman Kav. 1 Jakarta Selatan',    TIMESTAMP '2024-01-09 11:00:00.000000', TIMESTAMP '2024-01-09 11:00:00.000000'),
(50003, 20003, 10003, 'MOTOR',      'Yamaha',  'Mio M3 125 S',              2023, 'D 9012 GHI', 'E3S3E1234567', 'MH35F6012PK123456', 18000000.00, 0.8889, 'HELD',       'Jl. Asia Afrika No. 5 Bandung',           TIMESTAMP '2024-01-10 09:00:00.000000', TIMESTAMP '2024-01-10 09:00:00.000000'),
(50004, 20004, 10004, 'PROPERTI',   'N/A',     'Rumah Tinggal Type 36',     2010, NULL,          NULL,           NULL,               120000000.00, 0.4167, 'HELD',       'Jl. Pandanaran No. 10 Semarang',          TIMESTAMP '2024-01-11 10:00:00.000000', TIMESTAMP '2024-01-11 10:00:00.000000'),
(50005, 20005, 10005, 'ALAT_BERAT', 'Komatsu', 'PC200-8 Hydraulic Excavator',2020,'N/A',        'K200-8-00001', 'N/A',              950000000.00, 0.8421, 'HELD',       'Jl. Ahmad Yani No. 100 Surabaya',         TIMESTAMP '2024-01-12 08:00:00.000000', TIMESTAMP '2024-01-12 08:00:00.000000'),
(50006, 20006, 10006, 'MOTOR',      'Honda',   'Vario 160 CBS ISS',         2023, 'KT 2345 JKL', 'KF30E1234567','MH1KF300PNK12345', 25000000.00, 0.8000, 'HELD',       'Jl. Sudirman No. 30 Balikpapan',          TIMESTAMP '2024-01-15 10:30:00.000000', TIMESTAMP '2024-01-15 10:30:00.000000'),
(50007, 20007, 10007, 'MOBIL',      'Mitsubishi','Xpander Cross 1.5L MT',   2022, 'DD 6789 MNO', 'HA4W1234567', 'MMBGUK0F0NF123456',195000000.00,0.9231, 'HELD',       'Jl. Penghibur No. 5 Makassar',            TIMESTAMP '2024-01-17 11:30:00.000000', TIMESTAMP '2024-01-17 11:30:00.000000'),
(50008, 20008, 10008, 'MOBIL',      'Daihatsu', 'Ayla 1.2 X MT',           2021, 'BK 1010 PQR', 'GR11234567', 'MHKV5EA1MDK12345', 95000000.00, 0.9474, 'HELD',       'Jl. Gatot Subroto No. 8 Medan',           TIMESTAMP '2024-01-19 09:30:00.000000', TIMESTAMP '2024-01-19 09:30:00.000000'),
-- February 2024 registrations
(50009, 20011, 10009, 'MOTOR',      'Suzuki',  'Address 125',               2023, 'B 2020 STU', 'F910E1234567', 'MH8CF4110PJ12345', 17500000.00, 0.9143, 'HELD',       'Jl. Hayam Wuruk No. 15 Jakarta Barat',    TIMESTAMP '2024-02-05 09:30:00.000000', TIMESTAMP '2024-02-05 09:30:00.000000'),
(50010, 20012, 10010, 'MOBIL',      'Honda',   'BR-V 1.5 E CVT',           2022, 'B 3030 VWX', 'L15Z1234567', 'MHRRE2750NK12345', 210000000.00,0.9524, 'HELD',       'Jl. M.H. Thamrin No. 3 Bekasi',           TIMESTAMP '2024-02-06 10:30:00.000000', TIMESTAMP '2024-02-06 10:30:00.000000'),
(50011, 20017, 10015, 'ALAT_BERAT', 'Volvo',   'EC350E Hydraulic Excavator',2021,'N/A',         'D7E-12345',   'N/A',              700000000.00, 0.8571, 'HELD',       'Jl. Ring Road No. 50 Samarinda',          TIMESTAMP '2024-02-14 08:30:00.000000', TIMESTAMP '2024-02-14 08:30:00.000000');

SELECT COUNT(*) AS total_collateral FROM iceberg.multifinance_xyz.collateral;


-- ─────────────────────────────────────────────────────────────────────────────
-- Part C: Hidden partitioning queries — NO partition column in WHERE clause
-- ─────────────────────────────────────────────────────────────────────────────

-- QUERY 1: Filter by registered_at — Iceberg uses year+month transforms to prune
-- You write a normal date filter; Iceberg does the partition math for you.
SELECT collateral_id, collateral_type, brand, model, appraised_value
FROM iceberg.multifinance_xyz.collateral
WHERE registered_at >= TIMESTAMP '2024-02-01 00:00:00.000000'
ORDER BY registered_at;
-- Iceberg prunes year=2024/month=2024-01 → only reads February files


-- QUERY 2: truncate(collateral_type, 5) partition prune
-- 'MOTOR' → truncated to 'MOTOR' (5 chars = exact match)
-- 'ALAT_' → truncated to 'ALAT_' (5 chars of 'ALAT_BERAT')
SELECT
    collateral_type,
    brand,
    COUNT(*)                    AS count,
    SUM(appraised_value)        AS total_appraised_idr,
    AVG(ltv_ratio)              AS avg_ltv
FROM iceberg.multifinance_xyz.collateral
WHERE collateral_type = 'MOTOR'          -- Iceberg maps to truncate partition 'MOTOR'
GROUP BY collateral_type, brand
ORDER BY total_appraised_idr DESC;


-- QUERY 3: LTV analysis — vehicles with LTV > 90% (higher risk)
SELECT
    c.collateral_id,
    cust.full_name,
    c.collateral_type,
    c.brand,
    c.model,
    c.appraised_value,
    ROUND(c.ltv_ratio * 100, 2) AS ltv_pct,
    c.bpkb_status
FROM iceberg.multifinance_xyz.collateral c
JOIN iceberg.multifinance_xyz.customer cust ON c.customer_id = cust.customer_id
WHERE c.ltv_ratio > 0.90
ORDER BY c.ltv_ratio DESC;


-- QUERY 4: Inspect which partition dirs Iceberg created
SELECT partition, record_count, file_count
FROM iceberg.multifinance_xyz."$partitions"
ORDER BY partition;
