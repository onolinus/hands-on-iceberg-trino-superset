# 🧊 Iceberg + Trino + Superset — Hands-On Lab
### Multifinance XYZ Use Case

---

## Overview

This lab walks through **Apache Iceberg v2 features** using a realistic **multifinance domain** (loan applications, customers, disbursements, repayments) queried via **Trino** and visualized in **Apache Superset**.

Every module is a standalone SQL script you can run in sequence. Each script is heavily commented so you understand **why**, not just **what**.

---

## Prerequisites

| Component | Version | Notes |
|-----------|---------|-------|
| Trino | ≥ 420 | With Iceberg connector configured |
| Iceberg | Format v2 | Via Hive Metastore or REST catalog |
| Object Storage | OSS / S3 / HDFS | Adjust `location` per your environment |
| Superset | ≥ 3.x | Connected to Trino via SQLAlchemy |

> **OSS Location pattern used in this lab:**  
> `oss://xyz-iceberg.ap-southeast-5.oss-dls.aliyuncs.com/warehouse/<schema>/<table>`  
> Replace with your actual bucket and endpoint.

---

## Catalog & Schema Convention

```
catalog  : iceberg
schema   : multifinance_xyz
```

All tables live in `iceberg.multifinance_xyz.*`

---

## Lab Modules

```
00_setup/
│   └── 00_create_schema.sql          — Create catalog schema + OSS location

01_schema_evolution/
│   ├── 01a_create_customer.sql       — Base customer table
│   ├── 01b_insert_customers.sql      — Seed data
│   └── 01c_schema_evolution.sql      — ADD / DROP / RENAME / REORDER columns

02_time_travel/
│   ├── 02a_create_loan_application.sql
│   ├── 02b_insert_versions.sql       — Multiple INSERT batches to create snapshots
│   └── 02c_time_travel_queries.sql   — FOR VERSION AS OF / FOR TIMESTAMP AS OF

03_partitioning/
│   ├── 03a_create_disbursement.sql   — Multi-strategy partitioning
│   ├── 03b_insert_disbursement.sql
│   └── 03c_partition_queries.sql     — Partition pruning demo

04_merge_upsert/
│   ├── 04a_create_repayment.sql
│   ├── 04b_insert_repayment.sql
│   └── 04c_merge_upsert.sql          — MERGE INTO (upsert + soft delete)

05_hidden_partitioning/
│   ├── 05a_create_collateral.sql     — Hidden partition transforms
│   └── 05b_hidden_partition_demo.sql — Query without partition column filter

06_row_level_delete/
│   ├── 06a_create_blacklist.sql
│   ├── 06b_insert_blacklist.sql
│   └── 06c_row_level_delete.sql      — DELETE with predicate (position deletes)

07_snapshots_metadata/
│   └── 07_snapshot_metadata.sql      — $snapshots, $history, $files, $manifests

08_superset_views/
│   └── 08_superset_views.sql         — Gold-layer views for Superset dashboards

99_cleanup/
│   └── 99_drop_all.sql               — Clean teardown
```

---

## Feature Coverage Matrix

| Module | Iceberg Feature |
|--------|----------------|
| 01 | Schema Evolution (add/drop/rename columns) |
| 02 | Time Travel & Snapshot Isolation |
| 03 | Partition Spec v2 (month, bucket, identity) |
| 04 | MERGE INTO / Upsert / Copy-on-Write |
| 05 | Hidden Partitioning (no partition column in query) |
| 06 | Row-Level Deletes (position delete files) |
| 07 | Metadata Tables ($snapshots, $history, $files) |
| 08 | Gold Views for BI / Superset |

---

## Domain Model — Multifinance XYZ

```
customer ──────────────────────────────┐
  │                                    │
  └──< loan_application >──< disbursement >──< repayment_schedule >
              │
              └──< collateral >
              
blacklist  (standalone, used in MERGE demo)
```

### Business Context

**Multifinance XYZ** is a non-bank financial institution offering:
- **Vehicle financing** (motorcycle, car)  
- **Equipment financing** (heavy equipment, machinery)
- **Multipurpose loans**

Loan lifecycle: `SUBMITTED → SURVEYED → APPROVED → DISBURSED → ACTIVE → CLOSED / NPL`

---

## How to Run

1. Connect to Trino CLI or DBeaver pointed at your Trino endpoint
2. Run scripts in module order (`00` → `08`)
3. Each script is idempotent where noted — safe to re-run
4. Module `07` can be run after any other module to inspect metadata

```bash
# Example: Trino CLI
trino --server https://your-trino:8080 \
      --catalog iceberg \
      --schema multifinance_xyz \
      --file 00_setup/00_create_schema.sql
```

---

## Superset Setup

After running module `08`:

1. Add Trino as a database in Superset:
   - Engine: `trino`
   - SQLAlchemy URI: `trino://user@your-trino-host:8080/iceberg`
2. Import datasets from schema `iceberg.multifinance_xyz`
3. Use views prefixed `vw_` as Superset datasets
4. Recommended charts per view — see `08_superset_views/08_superset_views.sql` header

---

## Notes on `location`

Every `CREATE TABLE` has a `location` property. Adjust it to match your OSS/S3 bucket:

```sql
-- Template
location = 'oss://<your-bucket>/<your-prefix>/<schema>/<table>'

-- Example (this lab default)
location = 'oss://xyz-iceberg.ap-southeast-5.oss-dls.aliyuncs.com/warehouse/multifinance_xyz/customer'
```

If you use a Hive Metastore with a default warehouse path, you can omit `location` and it will auto-derive from the catalog's warehouse root.

---

*Lab version: 1.0 | Stack: Trino + Apache Iceberg v2 + Apache Superset*
