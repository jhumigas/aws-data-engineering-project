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
├── stored_procedures             <-- PL/pgSQL SCD Type 2 logic
├── validation                    <-- Data integrity and count checks
└── README.md
```

## Orchestration
These scripts are automatically applied during the warehouse initialization phase:
```bash
make setup-redshift
```

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
The stored procedures are also triggered as part of the main ETL Step Functions orchestration to perform automated SCD Type 2 merges.
