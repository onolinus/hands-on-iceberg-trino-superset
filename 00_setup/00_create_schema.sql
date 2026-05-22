-- =============================================================================
-- MODULE 00 | SETUP
-- File    : 00_create_schema.sql
-- Purpose : Create the working schema for Multifinance XYZ lab
-- Run     : Once, before all other modules
-- =============================================================================

-- Verify the Iceberg catalog is visible
SHOW CATALOGS;

-- Verify Iceberg catalog schemas
SHOW SCHEMAS FROM iceberg;

-- Create the lab schema
-- In Trino+Iceberg, the schema maps to a Hive Metastore database
-- and the warehouse root on object storage.
CREATE SCHEMA IF NOT EXISTS iceberg.multifinance_xyz

-- Confirm creation
SHOW SCHEMAS FROM iceberg LIKE 'multifinance%';

-- Set default context (run this at the top of every session)
USE iceberg.multifinance_xyz;
