# Spec: Glue and Redshift Data Pipeline Automation

This document outlines the design for automating the ETL pipeline from the S3 Bronze layer to the Redshift Data Warehouse, including schema discovery, transformation, and SCD Type 2 loading.

## 1. Architecture Overview

The pipeline follows a multi-stage approach:
1.  **Bronze (Raw)**: Glue Crawlers discover schema from DMS-replicated CSV files.
2.  **Silver (Cleaned)**: Glue Spark jobs transform raw CSV to enriched Parquet.
3.  **Redshift Staging**: Glue Load jobs perform bulk COPY from Silver S3 to Redshift temporary tables.
4.  **Gold (Warehouse)**: Redshift Stored Procedures apply SCD Type 2 logic to merge staging data into final Dimension/Fact tables.
5.  **Orchestration**: AWS Step Functions manages the sequential execution of all components.

## 2. Components

### 2.1. Glue Data Catalog (Bronze)
- **Database**: `aws_de_project_dev_db`
- **Crawlers**: 4 table-specific crawlers:
    - `crawler-customer`: `s3://<bucket>/bronze/dev/Customer/`
    - `crawler-orders`: `s3://<bucket>/bronze/dev/Orders/`
    - `crawler-products`: `s3://<bucket>/bronze/dev/Product/`
    - `crawler-orderdetails`: `s3://<bucket>/bronze/dev/orderDetails/`
- **Purpose**: Ensure schema changes in the source RDS are automatically reflected in the catalog.

### 2.2. Glue Spark Jobs (Silver)
- **Transform Jobs**: 4 jobs parameterized via Terraform `default_arguments`:
    - `--SOURCE_BUCKET`: The data lake bucket.
    - `--GLUE_DATABASE`: The Bronze catalog database.
    - `--TARGET_PREFIX`: `silver/dev/`
- **Scripts**: Updated to use `getResolvedOptions` to replace hardcoded strings.
- **Enrichment**:
    - Adds `hash_value` (SHA256 of business columns).
    - Adds `record_start_ts`, `record_end_ts`, and `active_flag`.
    - Enables **Job Bookmarks** for incremental processing.

### 2.3. Redshift Warehouse (Gold)
- **Provisioning**: Single-node RA3 cluster (managed via `modules/redshift`).
- **DDL Execution**: Terraform will apply the scripts in `data_warehouse_redshift/ddl/` to create schemas (`sales`) and tables.
- **Staging Tables**: Each target table has a corresponding `stage_` table (e.g., `sales.stage_dim_customer`).
- **Stored Procedures**: Leverages existing SQL logic in `data_warehouse_redshift/stored_procedures/` to handle SCD Type 2 logic.

### 2.4. Orchestration (Step Functions)
- **State Machine**: Sequential flow:
    1.  `StartCrawlers`: Parallel execution of all 4 crawlers.
    2.  `WaitForCrawlers`: Poll status until all are `READY`.
    3.  `RunTransformJobs`: Parallel Spark jobs (Bronze -> Silver).
    4.  `RunLoadJobs`: Parallel Spark jobs (Silver -> Redshift Staging).
    5.  `RunSQLMerge`: Sequential execution of Redshift Stored Procedures.
- **Trigger**: EventBridge cron rule (`rate(1 hour)`).

## 3. Infrastructure & Security

### 3.1. VPC Endpoints
To ensure secure and efficient communication within the private subnets, the following VPC Endpoints will be finalized:
- **S3 (Gateway)**: Bulk data movement.
- **Secrets Manager (Interface)**: Retrieving Redshift credentials.
- **Redshift (Interface)**: Glue connectivity.
- **STS (Interface)**: Temporary credential assumption for cross-service roles.

### 3.2. IAM Roles
- **Glue Role**: Access to S3 (Surgical bucket policy), Secrets Manager, and Redshift.
- **Step Functions Role**: Permission to trigger Glue and Redshift Data API.

## 4. Implementation Strategy

1.  **Refactor Glue Scripts**: Update Python files in `etl_glue_jobs/` to accept dynamic arguments.
2.  **Update Terraform Modules**:
    - `glue`: Add Crawler resources and dynamic job configuration.
    - `redshift`: Finalize endpoint configuration and DDL triggering (via `null_resource` or Data API).
    - `step_functions`: Construct the detailed JSON state machine definition.
3.  **End-to-End Test**: Trigger the Step Function manually and verify data in Redshift.
