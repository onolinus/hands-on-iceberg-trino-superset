-- =============================================================================
-- MODULE 99 | CLEANUP
-- File    : 99_drop_all.sql
-- Purpose : Teardown all lab objects. Run when you want a clean slate.
--           Tables are dropped in reverse dependency order.
-- WARNING : This is DESTRUCTIVE. All data and metadata will be removed.
--           Object storage files are NOT deleted by DROP TABLE — you need to
--           manually delete the OSS paths or run remove_orphan_files first.
-- =============================================================================

USE iceberg.multifinance_xyz;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 1: Drop Gold Views
-- ─────────────────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS iceberg.multifinance_xyz.vw_executive_kpi;
DROP VIEW IF EXISTS iceberg.multifinance_xyz.vw_collateral_coverage;
DROP VIEW IF EXISTS iceberg.multifinance_xyz.vw_loan_funnel;
DROP VIEW IF EXISTS iceberg.multifinance_xyz.vw_customer_acquisition;
DROP VIEW IF EXISTS iceberg.multifinance_xyz.vw_dpd_aging;
DROP VIEW IF EXISTS iceberg.multifinance_xyz.vw_portfolio_summary;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 2: Drop Tables (leaf tables first, then parent tables)
-- ─────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS iceberg.multifinance_xyz.blacklist;
DROP TABLE IF EXISTS iceberg.multifinance_xyz.repayment_schedule;
DROP TABLE IF EXISTS iceberg.multifinance_xyz.collateral;
DROP TABLE IF EXISTS iceberg.multifinance_xyz.disbursement;
DROP TABLE IF EXISTS iceberg.multifinance_xyz.loan_application;
DROP TABLE IF EXISTS iceberg.multifinance_xyz.customer;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 3: Drop Schema
-- ─────────────────────────────────────────────────────────────────────────────
DROP SCHEMA IF EXISTS iceberg.multifinance_xyz;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 4: Verify cleanup
-- ─────────────────────────────────────────────────────────────────────────────
SHOW SCHEMAS FROM iceberg;
-- multifinance_xyz should no longer appear

-- ─────────────────────────────────────────────────────────────────────────────
-- NOTE: OSS cleanup (run separately, outside Trino)
-- ─────────────────────────────────────────────────────────────────────────────
-- ossutil rm -rf oss://xyz-iceberg.ap-southeast-5.oss-dls.aliyuncs.com/warehouse/multifinance_xyz/
