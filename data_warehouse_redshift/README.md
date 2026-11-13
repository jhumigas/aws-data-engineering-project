# Data Warehouse (Amazon Redshift)

SQL scripts and stored procedures required to initialize and maintain the Amazon Redshift Data Warehouse.

## Pre-requisites
- **AWS CLI** configured with Redshift Data API permissions.
- **Redshift Cluster** provisioned and accessible.

## Folder Structure
```text
.
├── cleanup                       <-- Scripts to purge data for testing
├── ddl                           <-- Schema and Table creation scripts
├── stored_procedures             <-- PL/pgSQL merges: SCD Type 2 dimensions, fact upserts
├── validation                    <-- Data integrity and count checks
├── run_sql.sh                    <-- Runs SQL via the Data API and waits for each statement
└── README.md
```

## Orchestration
These scripts are automatically applied during the warehouse initialization phase:
```bash
make setup-redshift
```
The target runs every file through `run_sql.sh`, in order, and waits for each one.
It stops on the first Redshift error and prints it.
`ddl/schema_database.sql` is skipped, because `CREATE DATABASE` cannot run inside the Data API transaction.

### Manual Initialization
To manually initialize objects without the Makefile, use the **AWS Redshift Data API**:
```bash
# Example: Creating the schema
aws redshift-data execute-statement \
  --cluster-identifier <your-cluster-id> \
  --database dev \
  --db-user adminuser \
  --sql "CREATE SCHEMA IF NOT EXISTS sales;" \
  --region ca-central-1

# Repeat for DDL and Stored Procedure files:
aws redshift-data execute-statement ... --sql "$(cat path/to/file.sql)"
```
The stored procedures are also triggered as part of the main ETL Step Functions orchestration.
The dimension procedures (`sp_merge_dim_*`) perform SCD Type 2 merges, and the fact procedures (`sp_merge_fact_*`) upsert the latest version of each order and order line.
