# Terraform Infrastructure Walkthrough

This guide explains how to deploy the AWS Data Engineering Project infrastructure using the provided Terraform code and the centralized `Makefile` control plane.

## Prerequisites
- **Terraform** installed (v1.0+).
- **AWS CLI** configured with appropriate credentials (`aws configure`).
- **Python 3.x** and **uv** (for Lambda and Glue job packaging).
- **Docker** (for local migrations and BI tools).

## Deployment Steps

1. **Initialize and Build**:
   Navigate to the project root and build the Lambda package:
   ```bash
   make build-lambda
   ```

2. **Provision Infrastructure**:
   Deploy the AWS resources via Terraform:
   ```bash
   cd terraform && terraform init && terraform apply -auto-approve
   ```

   > [!NOTE]
   > **Parallel Provisioning**: RDS, DMS, and Redshift are provisioned in parallel to reduce deployment time (approx. 15 minutes).

3. **Initialize RDS (Flyway & CDC)**:
   Navigate back to the project root and run migrations to setup the source schema:
   ```bash
   make setup-rds
   ```

4. **Initialize Redshift Warehouse**:
   Establish the Redshift `sales` schema, tables, and SCD Type 2 procedures:
   ```bash
   make setup-redshift
   ```

5. **Discover Schema (Glue Crawlers)**:
   Trigger schema discovery for the raw data in S3:
   ```bash
   make trigger-crawlers
   ```
   *Note: Wait for all crawlers to show a status of 'READY' in the AWS Console before proceeding.*

6. **Trigger the Data Pipeline**:
   Start the end-to-end data flow:
   ```bash
   make trigger-dms      # Start CDC Replication
   make trigger-lambda   # Seed initial data
   make trigger-pipeline # Start Step Functions ETL
   ```

7. **Local Visualization (Optional)**:
   Spin up a local BI tool to explore the Redshift data:
   ```bash
   make run-metabase
   ```
   *Access at http://localhost:3000*

For a deep dive into the system's design, see the [Security Design](../SECURITY_DESIGN.md) and [Operations Guide](../OPERATIONS_GUIDE.md).

## Verification

1. **Check Infrastructure Outputs**:
   ```bash
   make tf-outputs
   ```

2. **Monitor Step Functions**: 
   Check the execution status in the AWS Console. The pipeline will:
   - Run Spark Jobs to transform CSV to Parquet.
   - Load data into Redshift Staging.
   - Run Stored Procedures for SCD Type 2 merge.

2. **Query the Warehouse**:
   Verify data existence via the Data API:
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
To destroy all cloud resources:
```bash
cd terraform && terraform destroy -auto-approve
```
