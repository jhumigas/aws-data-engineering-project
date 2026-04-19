# Terraform Infrastructure Walkthrough

This guide explains how to deploy the AWS Data Engineering Project infrastructure using the provided Terraform code.

## Prerequisites
- **Terraform** installed (v1.0+).
- **AWS CLI** configured with appropriate credentials (`aws configure`).
- **Python 3.x** and **uv** (for Lambda and Glue job packaging).

## Deployment Steps

1. **Navigate to the Terraform directory**:
   ```bash
   cd terraform
   ```

2. **Initialize and Apply**:
   ```bash
   terraform init
   terraform apply -auto-approve
   ```

   > [!NOTE]
   > **Parallel Provisioning**: RDS, DMS, and Redshift are provisioned in parallel to reduce deployment time.

3. **Manual RDS Configuration (CDC)**:
   Connect to the RDS instance and run:
   ```sql
   CALL mysql.rds_set_configuration('binlog retention hours', 24);
   ```

4. **Initialize Redshift Schema**:
   Since the cluster is private, use the Data API to establish the `sales` schema:
   ```bash
   aws redshift-data execute-statement \
     --cluster-identifier aws-de-project-dev-redshift \
     --database dev \
     --db-user adminuser \
     --sql "CREATE SCHEMA IF NOT EXISTS sales;" \
     --region ca-central-1
   ```
   *Note: Initialize all tables and procedures from `data_warehouse_redshift/ddl/` and `stored_procedures/` using this method.*

5. **Trigger the Pipeline**:
   Start the Step Functions state machine to run the end-to-end flow:
   ```bash
   aws stepfunctions start-execution \
     --state-machine-arn $(terraform output -raw state_machine_arn) \
     --region ca-central-1
   ```

## Verification

1. **Monitor Step Functions**: 
   Check the execution status in the AWS Console. The pipeline will:
   - Run Crawlers to discover schema.
   - Run Spark Jobs to transform CSV to Parquet.
   - Load data into Redshift Staging.
   - Run Stored Procedures for SCD Type 2 merge.

2. **Query the Warehouse**:
   ```bash
   aws redshift-data execute-statement \
     --cluster-identifier aws-de-project-dev-redshift \
     --database dev \
     --db-user adminuser \
     --sql "SELECT count(*) FROM sales.dim_customer;" \
     --region ca-central-1
   ```

## Resources Created
- **VPC**: Private network with S3, Secrets Manager, and Redshift endpoints.
- **S3**: Multi-layered Data Lake (Bronze/Silver/Scripts).
- **RDS**: MySQL source database with binary logging.
- **DMS**: CDC replication from RDS to S3.
- **Glue**: Serverless Crawlers and Spark ETL jobs.
- **Redshift**: RA3 cluster for data warehousing.
- **Step Functions**: Centralized ETL Orchestrator.

## Cleanup
To destroy all resources:
```bash
terraform destroy -auto-approve
```
