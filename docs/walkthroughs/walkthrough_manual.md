# Manual Infrastructure Setup Guide

This guide provides a detailed, step-by-step walkthrough for manually provisioning and configuring the AWS Data Engineering Project infrastructure using the AWS Management Console and CLI.

## Prerequisites
- **AWS Account** with administrative access.
- **AWS CLI** configured locally.
- **SQL Client** (e.g., DBeaver) for database interactions.

---

## Phase 1: Foundation and Source Database

### 0. User Permissions
Create an IAM user or role with administrative access to perform the subsequent provisioning steps.

### 1. RDS MySQL Setup
We use RDS to simulate an on-premise transactional source database.
- **Engine**: MySQL 8.0 Community Edition.
- **Instance Class**: `db.t3.micro` (Free Tier eligible).
- **Public Access**: Enable **Publicly Accessible** to allow local SQL client connectivity for initial setup.
- **Parameter Group**: 
    - Create a custom parameter group for MySQL 8.0.
    - Set `binlog_format = ROW`.
    - Set `binlog_row_image = FULL`.
    - Attach to the RDS instance (reboot required to apply).
- **Initialization**: 
    - Run the DDL script found in `application_db_rds/migration/V1__Initial_Schema.sql`.
- **CDC Configuration**:
    - Connect via SQL client and execute the binary logging retention command:
      ```sql
      CALL mysql.rds_set_configuration('binlog retention hours', 24);
      ```

---

## Phase 2: Storage and Replication

### 2. S3 Data Lake
Create a single S3 bucket to serve as the project's data lake.
- **Folders**: Create `bronze/` (for raw CSV) and `silver/` (for processed Parquet).
- **Policy**: Create a policy to allow Glue, DMS, and Redshift to access the bucket (see `docs/SECURITY_DESIGN.md` for role-specific prefixes).

### 3. DMS Replication (CDC)
Setup continuous data capture from RDS to S3.
- **Replication Instance**: Small instance (e.g., `dms.t3.medium`).
- **Endpoints**:
    - **Source**: Connect to the RDS instance. Test the connection.
    - **Target**: Connect to the S3 bucket. Ensure the service role has `s3:PutObject` permissions. Test the connection.
- **Replication Task**: 
    - **Migration Type**: Full load + CDC.
    - **Target Location**: `s3://<bucket>/bronze/`.
    - **Settings**: Ensure `AddColumnName=true` and `IncludeOpForFullLoad=true` are set in the S3 target settings to provide headers and operation metadata to Spark.

---

## Phase 3: Processing and Warehousing

### 4. Data Generation (Lambda)
Simulate real-time application traffic.
- **IAM Role**: Create a role with access to RDS and Secrets Manager.
- **Function**: Deploy the Python script from `data_generator_lambda/`.
- **Packaging**: Use `uv` for packaging to ensure `mysql-connector-python` and `Faker` are included.
- **Secrets Manager**: Store DB credentials (host, port, user, password) as a JSON secret.

### 5. Redshift Data Warehouse
- **Provisioning**: Create a Redshift RA3 cluster or a Serverless Workgroup/Namespace.
- **Network**: Ensure the cluster is accessible and VPC endpoints are configured (see Step 7).
- **Schema & Objects**: Establish the `sales` schema and run the DDLs/Stored Procedures in `data_warehouse_redshift/` to enable SCD Type 2 functionality.

### 6. Glue ETL (Transformation)
Process data from the Bronze layer to the Silver layer.
- **IAM Role**: Attach `AWSGlueServiceRole`, `AWSGlueNotebookRole`, and your custom S3 bucket policy.
- **Database**: Create a Glue Data Catalog database (e.g., `aws_de_project_db`).
- **Crawlers**: Create one crawler per Bronze folder to discover schema.
- **Spark Jobs**: Deploy the jobs from `etl_glue_jobs/transform/`. 
- **Bookmarks**: **Enable job bookmarks** to avoid reprocessing old data.

---

## Phase 4: Integration and Orchestration

### 7. Redshift Loading & VPC Networking
- **VPC Endpoints**: For private subnet communication, create endpoints for:
    - **S3** (Gateway)
    - **Secrets Manager** (Interface)
    - **Redshift** (Interface)
    - **STS** (Interface)
- **Glue Connection**: Create a "Redshift" connection type in Glue using the Redshift cluster's VPC, subnet, and security group.
- **Loading Jobs**: Deploy scripts from `etl_glue_jobs/load/` to move data from Silver S3 to Redshift staging.

### 8. Step Functions (Orchestration)
Sequence the entire pipeline logic.
- **IAM Role**: Grant Step Functions permission to trigger Glue and Redshift Data API (attach `AWSGlueServiceRole`).
- **State Machine**: Use the definition provided in `orchestration_step_function/state_machine.json`.

---

## Phase 5: Automation and Governance

### 9. Visualization (QuickSight / BI)
- Sign up for QuickSight in the same region.
- Create a dataset connecting to Redshift (ensure QuickSight has VPC access if the cluster is private).
- Build a dashboard using dimension and fact tables.

### 10. Scheduling (EventBridge)
- **Rule 1**: Trigger the Lambda Data Generator (e.g., every 5 minutes).
- **Rule 2**: Trigger the Step Functions State Machine (e.g., every hour).
- **Note**: Before enabling schedules, ensure all intermediate data is purged and Glue job bookmarks are reset for a clean production run.

### 11. PII Management (Lake Formation)
Implement data governance for sensitive information.
- Set up a **Lake Formation Administrator**.
- Register S3 data lake locations.
- Create a **Data Analyst Role** with a trust policy allowing assumption.
- Implement **LF-Tags** for PII classification.
- Apply tags to tables and columns to restrict access to PII data.

### 12. Cleanup
Once satisfied, destroy all AWS resources via the console or CLI to avoid unnecessary costs.
