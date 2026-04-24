# Manual Infrastructure Setup Guide

This guide provides a step-by-step walkthrough for manually provisioning and configuring the AWS Data Engineering Project infrastructure using the AWS Management Console and CLI.

## Prerequisites
- **AWS Account** with administrative access.
- **AWS CLI** configured locally.
- **SQL Client** (e.g., DBeaver) for database interactions.

---

## Phase 1: Foundation and Source Database

### 1. User Permissions
Create an IAM user or role with administrative access to perform the subsequent provisioning steps.

### 2. RDS MySQL Setup
We use RDS to simulate a transactional source database.
- **Provisioning**: Create a MySQL 8.0 Community Edition instance (Free Tier eligible: `db.t3.micro`).
- **Network**: Ensure the instance is **Publicly Accessible** for local SQL client connectivity.
- **Parameter Group**: 
    - Create a custom parameter group.
    - Set `binlog_format = ROW` and `binlog_row_image = FULL`.
    - Attach to the RDS instance (requires reboot).
- **Initialization**: 
    - Run the DDL script found in `db/migration/V1__Initial_Schema.sql`.
- **CDC Configuration**:
    - Connect via SQL client and run:
      ```sql
      CALL mysql.rds_set_configuration('binlog retention hours', 24);
      ```

---

## Phase 2: Storage and Replication

### 3. S3 Data Lake
Create a single S3 bucket to serve as the project's data lake.
- **Structure**: Create top-level folders: `bronze/` and `silver/`.
- **Policy**: Attach a policy allowing DMS, Glue, and Redshift to access their respective prefixes (see `docs/SECURITY_DESIGN.md`).

### 4. DMS Replication
Setup the continuous data capture (CDC) from RDS to S3.
- **Replication Instance**: Provision a small instance in a public/private subnet.
- **Endpoints**:
    - **Source**: Connect to the RDS instance using Secrets Manager credentials.
    - **Target**: Connect to the S3 bucket with a role allowing `s3:PutObject`.
- **Replication Task**: 
    - Type: **Full load + CDC**.
    - Target: `s3://<bucket>/bronze/`.
    - Enable headers: Set `AddColumnName=true` and `IncludeOpForFullLoad=true`.

---

## Phase 3: Processing and Warehousing

### 5. Data Generation (Lambda)
Simulate live application traffic.
- **Function**: Deploy the Python script from `data_generator_lambda/`.
- **Packaging**: Use `uv` to bundle dependencies (`mysql-connector-python`, `Faker`).
- **Scheduling**: Create an EventBridge rule to trigger the Lambda every 5 minutes.

### 6. Redshift Data Warehouse
- **Provisioning**: Create an RA3 single-node cluster (or Serverless workgroup).
- **Schema**: Create the `sales` schema using the Data API or SQL client.
- **Objects**: Run the DDLs and Stored Procedures found in `data_warehouse_redshift/`.

### 7. Glue ETL (Spark)
- **Catalog**: Run Glue Crawlers on the `bronze/` folder to discover the schema.
- **Transform**: Deploy Spark jobs to clean data and convert to Parquet in the `silver/` layer.
- **Load**: Deploy jobs to load Parquet data into Redshift staging tables.

---

## Phase 4: Orchestration and Visualization

### 8. Step Functions
Create a state machine to sequence the pipeline:
1. Parallel Load Dimensions (Customer, Product).
2. Redshift Merge (Stored Procedures).
3. Parallel Load Facts (Orders, OrderDetails).

### 9. QuickSight / BI
- Connect QuickSight (or local Metabase/Superset) to the Redshift cluster.
- Build visualizations using the `sales.dim_customer` and `sales.fact_orders` tables.

---

## Phase 5: Governance and Cleanup

### 10. PII Management (Lake Formation)
- Set up Lake Formation administrators.
- Register S3 locations.
- Implement LF-Tags for PII classification on sensitive columns (e.g., customer names).

### 11. Cleanup
Destroy all resources via the console or CLI to avoid ongoing costs when the project is complete.
