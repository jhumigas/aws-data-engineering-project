# Terraform Infrastructure Walkthrough

This guide explains how to deploy the AWS Data Engineering Project infrastructure using the provided Terraform code.

## Prerequisites
- **Terraform** installed (v1.0+).
- **AWS CLI** configured with appropriate credentials (`aws configure`).
- **Python 3.x** (for Lambda packaging if running locally, handled by Terraform).

## Deployment Steps

1. **Navigate to the Terraform directory**:
   ```bash
   cd terraform
   ```

2. **Initialize Terraform**:
   Downloads providers and modules.
   ```bash
   terraform init
   ```

3. **Validate Configuration**:
   Ensures syntax is correct.
   ```bash
   terraform validate
   ```

4. **Review Plan**:
   See what resources will be created.
   ```bash
   terraform plan
   ```

5. **Apply Configuration**:
   Provision the resources. You will be prompted to type `yes`.
   ```bash
   terraform apply
   ```

   > [!NOTE]
   > **Parallel Provisioning**: RDS and DMS instances are provisioned in parallel to reduce deployment time (approx. 10-15 minutes total). While the compute infrastructure is built concurrently, the data replication task is automatically configured to wait until the RDS schema is fully initialized via Flyway. The endpoint test connection to the database might fail if the database is not yet accessible.

6. **Manual RDS Configuration (CDC)**:
   Connect to the RDS instance (e.g., using DBeaver) and run the following command to finalize the binlog retention for CDC:
   ```sql
   CALL mysql.rds_set_configuration('binlog retention hours', 24);
   ```

7. **Manual Redshift Configuration (DDL)**:
   Since the Redshift cluster is private, use the AWS CLI (Data API) to create the `sales` schema and initialize tables. This ensures the Glue jobs have a target to load data into:
   ```bash
   # Create schema
   aws redshift-data execute-statement \
     --cluster-identifier aws-de-project-dev-redshift \
     --database dev \
     --db-user adminuser \
     --sql "CREATE SCHEMA IF NOT EXISTS sales;" \
     --region ca-central-1
   ```
   *Note: Repeat for all table DDLs and stored procedures provided in the `data_warehouse_redshift/` directory.*

8. **Trigger the Data Pipeline**:
   Start the Step Functions state machine to orchestrate the end-to-end ETL flow:
   ```bash
   aws stepfunctions start-execution \
     --state-machine-arn $(terraform output -raw state_machine_arn) \
     --region ca-central-1
   ```

## Resources Created
The following key resources are provisioned:
- **VPC**: Custom VPC with public/private subnets and endpoints.
- **S3**: `*-data-bucket` with `bronze`, `silver`, and `scripts` folders.
- **RDS**: MySQL instance (`sales_db`) with CDC parameters enabled.
- **DMS**: Replication instance, endpoints, and task for CDC from RDS to S3.
- **Lambda**: `data-generator` function scheduled via EventBridge to insert data into RDS.
- **Redshift**: Single-node cluster (`dev` database) for data warehousing.
- **Glue**:
    - Database (`*_db`)
    - Crawler (`bronze-crawler`)
    - Jobs (uploaded from `etl_glue_jobs/`)
- **Step Functions**: State machine to orchestrate Glue jobs.

## Verification
After `terraform apply` completes:
1. **Check S3**: Confirm the bucket exists and folders are created.
2. **Check RDS**: Verify the `sales_db` is accessible (via Lambda or bastion).
3. **Check Glue**: See the jobs listed providing the `etl_glue_jobs` scripts.
4. **Check Step Functions**: Trigger the state machine to test the flow.

## Cleanup
To destroy all resources:
```bash
terraform destroy
```

> [!CAUTION]
> This will delete all data in the RDS, Redshift, and S3 buckets (since `force_destroy` is enabled for demo).