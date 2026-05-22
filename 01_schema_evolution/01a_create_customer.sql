-- =============================================================================
-- MODULE 01 | SCHEMA EVOLUTION
-- File    : 01a_create_customer.sql
-- Purpose : Create the base customer table — intentionally INCOMPLETE columns
--           so we can add/drop/rename them in 01c to demo schema evolution.
-- Feature : Iceberg stores full schema history; old files still readable after
--           column changes because Iceberg tracks column IDs, not names.
-- =============================================================================

USE iceberg.multifinance_xyz;

-- Drop if re-running the lab
DROP TABLE IF EXISTS iceberg.multifinance_xyz.customer;

-- Initial schema — missing several columns on purpose (we add them in 01c)
CREATE TABLE iceberg.multifinance_xyz.customer (
    customer_id     bigint          COMMENT 'Surrogate PK — generated externally (Kafka / app layer)',
    nik             varchar(16)     COMMENT 'Nomor Induk Kependudukan (national ID)',
    full_name       varchar(255)    COMMENT 'Full legal name per KTP',
    phone           varchar(20)     COMMENT 'Primary mobile number',
    city            varchar(100)    COMMENT 'Domicile city',
    province        varchar(100)    COMMENT 'Domicile province',
    segment         varchar(50)     COMMENT 'Customer segment: MASS | MIDDLE | PREMIUM',
    created_at      timestamp(6)    COMMENT 'Record creation timestamp',
    is_deleted      boolean         COMMENT 'Soft-delete flag'
)
WITH (
    format          = 'PARQUET',
    format_version  = 2,
    -- Partition by month of onboarding — useful for range queries on created_at
    partitioning    = ARRAY['month(created_at)', 'province'],
    location        = 'oss://xyz-iceberg.ap-southeast-5.oss-dls.aliyuncs.com/warehouse/multifinance_xyz/customer'
);

-- Verify table created with correct spec
SHOW CREATE TABLE iceberg.multifinance_xyz.customer;
