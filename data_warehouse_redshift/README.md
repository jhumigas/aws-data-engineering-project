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
The stored procedures are also triggered as part of the main ETL Step Functions orchestration to perform automated SCD Type 2 merges.
