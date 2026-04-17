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

6. **Manual RDS Configuration (CDC)**:
   Connect to the RDS instance (e.g., using DBeaver) and run the following command to finalize the binlog retention for CDC:
   ```sql
   CALL mysql.rds_set_configuration('binlog retention hours', 24);
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