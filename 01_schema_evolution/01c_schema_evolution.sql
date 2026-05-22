-- =============================================================================
-- MODULE 01 | SCHEMA EVOLUTION
-- File    : 01c_schema_evolution.sql
-- Purpose : Demonstrate Iceberg's schema evolution capabilities.
--
-- KEY CONCEPT: Iceberg tracks columns by INTEGER ID, not by name.
-- This means:
--   - Old Parquet files written before a column was added → return NULL for that column
--   - Old files written before a column was dropped → simply ignore that column
--   - Old files written before a rename → serve data under the NEW name
--   - NO rewrite of existing data files needed for schema changes
--
-- All operations below are METADATA-ONLY — zero data file rewrites.
-- =============================================================================

USE iceberg.multifinance_xyz;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 1: Inspect current schema
-- ─────────────────────────────────────────────────────────────────────────────
DESCRIBE iceberg.multifinance_xyz.customer;


-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 2: ADD columns
-- Business need: risk team needs date of birth and marital status.
-- Old rows will return NULL for these new columns — safe, no rewrite.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE iceberg.multifinance_xyz.customer
    ADD COLUMN date_of_birth date COMMENT 'DOB per KTP';

ALTER TABLE iceberg.multifinance_xyz.customer
    ADD COLUMN marital_status varchar(20) COMMENT 'SINGLE | MARRIED | DIVORCED | WIDOWED';

ALTER TABLE iceberg.multifinance_xyz.customer
    ADD COLUMN email varchar(255) COMMENT 'Contact email — optional';

ALTER TABLE iceberg.multifinance_xyz.customer
    ADD COLUMN monthly_income decimal(18,2) COMMENT 'Self-reported monthly income in IDR';

-- Verify
DESCRIBE iceberg.multifinance_xyz.customer;


-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 3: Read old data — new columns return NULL
-- ─────────────────────────────────────────────────────────────────────────────
SELECT customer_id, full_name, date_of_birth, marital_status, monthly_income
FROM iceberg.multifinance_xyz.customer
LIMIT 5;
-- ^ All new columns will be NULL for existing rows — correct, safe, no data loss


-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 4: RENAME a column
-- Business need: 'phone' is ambiguous — rename to 'phone_primary'
-- Iceberg changes only the name in the schema metadata; column ID stays same.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE iceberg.multifinance_xyz.customer
    RENAME COLUMN phone TO phone_primary;

-- Confirm rename worked
SELECT customer_id, full_name, phone_primary
FROM iceberg.multifinance_xyz.customer
LIMIT 3;


-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 5: DROP a column
-- Business need: 'monthly_income' is now sourced from the gold layer; drop it.
--
-- IMPORTANT — Parquet position-mapping constraint:
--   Trino's Iceberg connector reads Parquet files by *column position*, not by
--   Iceberg column ID. Dropping a column from the MIDDLE of the schema shifts
--   the positions of all subsequent columns, making existing data files
--   unreadable (type-position mismatch → "incompatible columns" error).
--
--   Rule of thumb: only DROP the last-added (trailing) column safely.
--   Column order added: date_of_birth → marital_status → email → monthly_income
--   So monthly_income is the safe one to drop here.
--   To "drop" a middle column cleanly, use CTAS to rebuild the table.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE iceberg.multifinance_xyz.customer
    DROP COLUMN monthly_income;

DESCRIBE iceberg.multifinance_xyz.customer;


-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 6: UPDATE rows with new column values
-- ─────────────────────────────────────────────────────────────────────────────
UPDATE iceberg.multifinance_xyz.customer
SET
    date_of_birth  = DATE '1985-06-15',
    marital_status = 'MARRIED',
    email          = 'budi.santoso@email.com'
WHERE customer_id = 10001;

UPDATE iceberg.multifinance_xyz.customer
SET
    date_of_birth  = DATE '1990-03-22',
    marital_status = 'SINGLE',
    email          = 'siti.rahma@email.com'
WHERE customer_id = 10002;

UPDATE iceberg.multifinance_xyz.customer
SET
    date_of_birth  = DATE '1988-11-08',
    marital_status = 'MARRIED',
    email          = 'andi.wijaya@email.com'
WHERE customer_id = 10003;


-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 7: Final schema state
-- ─────────────────────────────────────────────────────────────────────────────
DESCRIBE iceberg.multifinance_xyz.customer;

SELECT * FROM iceberg.multifinance_xyz.customer
ORDER BY customer_id
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 8: How many snapshots did schema evolution create?
-- Note: ADD/RENAME/DROP column = metadata only, no new snapshot
--       UPDATE rows = new snapshot with data files
-- ─────────────────────────────────────────────────────────────────────────────
SELECT snapshot_id, committed_at, operation,
       element_at(summary, 'added-records')   AS added_records,
       element_at(summary, 'deleted-records') AS deleted_records,
       element_at(summary, 'total-records')   AS total_records
FROM iceberg.multifinance_xyz."customer$snapshots"
ORDER BY committed_at;
