# Terraform Infrastructure Walkthrough

This guide explains how to deploy the AWS Data Engineering Project infrastructure using the provided Terraform code.

## Prerequisites
- **Terraform** installed (v1.0+).
- **AWS CLI** configured with appropriate credentials (`aws configure`).
- **Python 3.x** and **uv** (for Lambda and Glue job packaging).
## Deployment Steps

1. **Navigate to the Project root**:
   ```bash
   cd ..
   ```

2. **Initialize and Apply**:
   ```bash
   cd terraform && terraform init && terraform apply -auto-approve
   ```

   > [!NOTE]
   > **Parallel Provisioning**: RDS, DMS, and Redshift are provisioned in parallel to reduce deployment time.

3. **Manual RDS Configuration (CDC)**:
   Run the Flyway migrations to setup the RDS source schema and enable CDC:
   ```bash
   make setup-rds
   ```

4. **Initialize Redshift Schema**:
   Use the Makefile to establish the `sales` schema, tables, and procedures:
   ```bash
   make setup-redshift
   ```

5. **Discover Schema**:
   Run the Glue Crawlers to discover the schema from the Bronze S3 folders:
   ```bash
   for crawler in aws-de-project-dev-crawler-Customer aws-de-project-dev-crawler-Orders aws-de-project-dev-crawler-Product aws-de-project-dev-crawler-orderDetails; do
     aws glue start-crawler --name $crawler --region ca-central-1
   done
   ```
   *Note: Wait for all crawlers to show a status of 'READY' before proceeding.*

6. **Trigger the Data Pipeline**:
   Start the pipeline using the Makefile:
   ```bash
   make trigger-dms
   make trigger-lambda
   make trigger-pipeline
   ```



## Verification

1. **Monitor Step Functions**: 
   Check the execution status in the AWS Console. The pipeline will:
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
