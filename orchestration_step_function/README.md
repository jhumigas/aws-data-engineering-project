# Step Functions Orchestration

Original Amazon States Language (ASL) reference for the ETL pipeline orchestrator.

## Pre-requisites
- **Step Functions Role** with Glue and Redshift Data API permissions.

## Folder Structure
```text
.
├── state_machine.json            <-- Raw ASL definition (Reference)
└── README.md
```

## Implementation
While this directory contains the reference definition, the active orchestration logic is managed via the **Terraform Step Functions module**, which implements a sequential flow optimized for referential integrity:
1. Glue Crawlers refresh the bronze tables in the Data Catalog (one per table, awaited until `SUCCEEDED`).
2. Parallel Transform jobs convert bronze CSV into silver Parquet.
3. Parallel Dimension loads (Customer/Product) followed by the SCD Type 2 merges (`sp_merge_dim_*`).
4. Parallel Fact loads (Orders/OrderDetails) followed by the fact upserts (`sp_merge_fact_*`).

Every Redshift merge is polled with `describeStatement` until it reaches `FINISHED`.
A `FAILED` or `ABORTED` merge fails the execution, so a green run means the warehouse is up to date.
