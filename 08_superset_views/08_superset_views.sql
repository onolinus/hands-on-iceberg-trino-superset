-- =============================================================================
-- MODULE 08 | GOLD-LAYER VIEWS FOR SUPERSET
-- File    : 08_superset_views.sql
-- Purpose : Create semantic views for Superset dashboards.
--           These are the Gold layer — business-friendly column names,
--           pre-joined, pre-aggregated where appropriate.
--
-- SUPERSET SETUP GUIDE (after running this script):
--   1. Database → Add Database → Engine: Trino
--      SQLAlchemy URI: trino://user@<host>:8080/iceberg
--   2. Datasets → Add Dataset:
--      Database: Trino | Schema: multifinance_xyz | Table: vw_*
--   3. Recommended chart types per view:
--      vw_portfolio_summary      → Big Number, Bar Chart, Table
--      vw_dpd_aging              → Heatmap, Grouped Bar Chart
--      vw_customer_acquisition   → Line Chart (by month), Map (by province)
--      vw_loan_funnel            → Funnel Chart, Sankey
--      vw_collateral_coverage    → Scatter Plot (LTV vs amount), Pie Chart
-- =============================================================================

USE iceberg.multifinance_xyz;

-- ─────────────────────────────────────────────────────────────────────────────
-- VIEW 1: Portfolio Summary
-- Answer: What does our active loan book look like today?
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW iceberg.multifinance_xyz.vw_portfolio_summary AS
SELECT
    d.product_type                                      AS product_type,
    d.branch_code                                       AS branch_code,
    DATE_FORMAT(d.disbursement_date, '%Y-%m')           AS disbursement_month,
    d.loan_status                                       AS loan_status,
    COUNT(DISTINCT d.disbursement_id)                   AS total_contracts,
    COUNT(DISTINCT d.customer_id)                       AS unique_customers,
    SUM(d.disbursed_amount)                             AS total_disbursed_idr,
    SUM(d.outstanding_principal)                        AS total_outstanding_idr,
    AVG(d.disbursed_amount)                             AS avg_contract_size_idr,
    MIN(d.disbursed_amount)                             AS min_contract_idr,
    MAX(d.disbursed_amount)                             AS max_contract_idr,
    -- Yield indicator: interest income potential
    SUM(d.disbursed_amount * la.interest_rate_pa)       AS annual_interest_income_idr,
    AVG(la.tenor_months)                                AS avg_tenor_months,
    AVG(la.interest_rate_pa) * 100                      AS avg_interest_rate_pct
FROM iceberg.multifinance_xyz.disbursement d
JOIN iceberg.multifinance_xyz.loan_application la
    ON d.application_id = la.application_id
GROUP BY 1, 2, 3, 4;

-- Test
SELECT * FROM iceberg.multifinance_xyz.vw_portfolio_summary
ORDER BY total_disbursed_idr DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- VIEW 2: DPD Aging Report
-- Answer: How much of our portfolio is overdue, and by how many days?
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW iceberg.multifinance_xyz.vw_dpd_aging AS
SELECT
    rs.collection_bucket                                AS dpd_bucket,
    d.product_type                                      AS product_type,
    d.branch_code                                       AS branch_code,
    DATE_FORMAT(rs.due_date, '%Y-%m')                   AS due_month,
    COUNT(DISTINCT rs.disbursement_id)                  AS contracts_in_bucket,
    COUNT(rs.schedule_id)                               AS installments_in_bucket,
    SUM(rs.total_due)                                   AS total_due_idr,
    SUM(rs.paid_amount)                                 AS total_paid_idr,
    SUM(rs.total_due - COALESCE(rs.paid_amount, 0))     AS total_outstanding_idr,
    SUM(rs.penalty_amount)                              AS total_penalty_idr,
    AVG(rs.days_past_due)                               AS avg_dpd,
    MAX(rs.days_past_due)                               AS max_dpd
FROM iceberg.multifinance_xyz.repayment_schedule rs
JOIN iceberg.multifinance_xyz.disbursement d
    ON rs.disbursement_id = d.disbursement_id
WHERE rs.payment_status IN ('CURRENT', 'OVERDUE', 'PAID')
GROUP BY 1, 2, 3, 4;

SELECT * FROM iceberg.multifinance_xyz.vw_dpd_aging ORDER BY dpd_bucket;


-- ─────────────────────────────────────────────────────────────────────────────
-- VIEW 3: Customer Acquisition Trend
-- Answer: How many new customers are we onboarding per month by segment/province?
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW iceberg.multifinance_xyz.vw_customer_acquisition AS
SELECT
    DATE_FORMAT(c.created_at, '%Y-%m')                  AS onboarding_month,
    c.province                                           AS province,
    c.city                                               AS city,
    c.marital_status                                     AS marital_status,
    COUNT(DISTINCT c.customer_id)                        AS new_customers,
    COUNT(DISTINCT la.application_id)                    AS applications_submitted,
    COUNT(DISTINCT CASE WHEN la.status = 'APPROVED'  THEN la.application_id END) AS approved,
    COUNT(DISTINCT CASE WHEN la.status = 'REJECTED'  THEN la.application_id END) AS rejected,
    COUNT(DISTINCT CASE WHEN la.status = 'DISBURSED' OR la.status = 'ACTIVE'
                        THEN la.application_id END)      AS disbursed,
    -- Conversion rate
    ROUND(
        CAST(COUNT(DISTINCT CASE WHEN la.status IN ('DISBURSED','ACTIVE') THEN la.application_id END) AS double)
        / NULLIF(COUNT(DISTINCT la.application_id), 0) * 100,
    2)                                                   AS conversion_rate_pct
FROM iceberg.multifinance_xyz.customer c
LEFT JOIN iceberg.multifinance_xyz.loan_application la
    ON c.customer_id = la.customer_id
WHERE c.is_deleted = false
GROUP BY 1, 2, 3, 4;

SELECT * FROM iceberg.multifinance_xyz.vw_customer_acquisition
ORDER BY onboarding_month, new_customers DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- VIEW 4: Loan Application Funnel
-- Answer: What is our drop-off at each stage of the lending pipeline?
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW iceberg.multifinance_xyz.vw_loan_funnel AS
SELECT
    DATE_FORMAT(application_date, '%Y-%m')              AS application_month,
    product_type                                         AS product_type,
    branch_code                                          AS branch_code,
    COUNT(*)                                             AS total_submitted,
    COUNT(CASE WHEN status = 'SURVEYED'  THEN 1 END)    AS surveyed,
    COUNT(CASE WHEN status IN ('APPROVED','DISBURSED','ACTIVE','CLOSED') THEN 1 END) AS approved,
    COUNT(CASE WHEN status = 'REJECTED'  THEN 1 END)    AS rejected,
    COUNT(CASE WHEN status IN ('DISBURSED','ACTIVE','CLOSED') THEN 1 END) AS disbursed,
    -- Funnel rates
    ROUND(
        CAST(COUNT(CASE WHEN status = 'SURVEYED' THEN 1 END) AS double)
        / NULLIF(COUNT(*), 0) * 100, 2)                  AS survey_rate_pct,
    ROUND(
        CAST(COUNT(CASE WHEN status IN ('APPROVED','DISBURSED','ACTIVE') THEN 1 END) AS double)
        / NULLIF(COUNT(CASE WHEN status = 'SURVEYED' THEN 1 END), 0) * 100, 2)  AS approval_rate_pct,
    ROUND(
        CAST(COUNT(CASE WHEN status IN ('DISBURSED','ACTIVE') THEN 1 END) AS double)
        / NULLIF(COUNT(CASE WHEN status IN ('APPROVED','DISBURSED','ACTIVE') THEN 1 END), 0) * 100, 2) AS disbursement_rate_pct,
    SUM(loan_amount)                                     AS total_requested_idr,
    AVG(loan_amount)                                     AS avg_requested_idr,
    AVG(tenor_months)                                    AS avg_tenor,
    AVG(interest_rate_pa) * 100                          AS avg_rate_pct
FROM iceberg.multifinance_xyz.loan_application
GROUP BY 1, 2, 3;

SELECT * FROM iceberg.multifinance_xyz.vw_loan_funnel
ORDER BY application_month, total_submitted DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- VIEW 5: Collateral Coverage
-- Answer: Is our collateral adequately covering the outstanding loan?
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW iceberg.multifinance_xyz.vw_collateral_coverage AS
SELECT
    col.collateral_type                                  AS collateral_type,
    col.brand                                            AS brand,
    col.manufacture_year                                 AS manufacture_year,
    d.product_type                                       AS product_type,
    d.branch_code                                        AS branch_code,
    COUNT(DISTINCT col.collateral_id)                    AS collateral_count,
    SUM(col.appraised_value)                             AS total_appraised_idr,
    SUM(d.outstanding_principal)                         AS total_outstanding_idr,
    -- Coverage ratio: appraised / outstanding (>1 = overcollateralized = good)
    ROUND(
        SUM(col.appraised_value) / NULLIF(SUM(d.outstanding_principal), 0),
    4)                                                   AS coverage_ratio,
    AVG(col.ltv_ratio) * 100                             AS avg_ltv_pct,
    MAX(col.ltv_ratio) * 100                             AS max_ltv_pct,
    COUNT(CASE WHEN col.bpkb_status = 'HELD'     THEN 1 END) AS bpkb_held,
    COUNT(CASE WHEN col.bpkb_status = 'RELEASED' THEN 1 END) AS bpkb_released
FROM iceberg.multifinance_xyz.collateral col
JOIN iceberg.multifinance_xyz.loan_application la
    ON col.application_id = la.application_id
JOIN iceberg.multifinance_xyz.disbursement d
    ON la.application_id = d.application_id
GROUP BY 1, 2, 3, 4, 5;

SELECT * FROM iceberg.multifinance_xyz.vw_collateral_coverage
ORDER BY total_outstanding_idr DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- VIEW 6: Executive Summary (single-row KPIs)
-- Answer: What is our top-line portfolio health right now?
-- Use in Superset as Big Number tiles on an executive dashboard.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW iceberg.multifinance_xyz.vw_executive_kpi AS
SELECT
    COUNT(DISTINCT d.disbursement_id)                           AS total_active_contracts,
    COUNT(DISTINCT d.customer_id)                               AS total_unique_customers,
    SUM(d.disbursed_amount)                                     AS total_disbursed_idr,
    SUM(d.outstanding_principal)                                AS total_outstanding_idr,
    -- NPL ratio (outstanding on NPL / total outstanding)
    ROUND(
        SUM(CASE WHEN d.loan_status = 'NPL' THEN d.outstanding_principal ELSE 0 END)
        / NULLIF(SUM(d.outstanding_principal), 0) * 100,
    2)                                                          AS npl_ratio_pct,
    -- Avg contract size
    AVG(d.disbursed_amount)                                     AS avg_contract_size_idr,
    -- Product mix
    COUNT(CASE WHEN d.product_type = 'MOTOR'      THEN 1 END)  AS motor_contracts,
    COUNT(CASE WHEN d.product_type = 'MOBIL'      THEN 1 END)  AS mobil_contracts,
    COUNT(CASE WHEN d.product_type = 'ALAT_BERAT' THEN 1 END)  AS alat_berat_contracts,
    COUNT(CASE WHEN d.product_type = 'MULTIGUNA'  THEN 1 END)  AS multiguna_contracts,
    -- Collection health
    SUM(CASE WHEN rs.collection_bucket != 'CURRENT' THEN rs.total_due ELSE 0 END) AS overdue_receivables_idr
FROM iceberg.multifinance_xyz.disbursement d
LEFT JOIN iceberg.multifinance_xyz.repayment_schedule rs
    ON d.disbursement_id = rs.disbursement_id
    AND rs.payment_status = 'OVERDUE';

SELECT * FROM iceberg.multifinance_xyz.vw_executive_kpi;


-- ─────────────────────────────────────────────────────────────────────────────
-- List all created views
-- ─────────────────────────────────────────────────────────────────────────────
SHOW VIEWS FROM iceberg.multifinance_xyz;
