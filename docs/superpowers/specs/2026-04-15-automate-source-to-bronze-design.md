# Design Spec: Automated Source to Bronze Deployment

**Date**: 2026-04-15  
**Topic**: Automating the complete flow from RDS creation to S3 Bronze landing.

## 1. Overview
The goal is to automate the manual steps currently described in `docs/NOTES.md` for Step 1 through Step 4. This ensures that a single `terraform apply` results in a functional data stream landing in S3.

## 2. Proposed Changes

### 2.1 Schema Management (Flyway)
*   **Structure**: Create `db/migration/` folder.
*   **Scripts**:
    *   `V1__Initial_Schema.sql`: Creates `Product`, `Customer`, `Orders`, and `orderDetails` tables.
    *   `V2__Configure_CDC.sql`: Sets binlog retention and other MySQL-specific CDC requirements.
*   **Automation**: A `null_resource` in Terraform will execute:
    ```bash
    flyway -url="jdbc:mysql://${rds_endpoint}/dev" \
           -user="${rds_user}" \
           -password="${rds_password}" \
           -locations="filesystem:db/migration" \
           migrate
    ```

### 2.2 Replication & Generation Automation
*   **DMS Start**: A `null_resource` will use the AWS CLI to start the DMS replication task after the Flyway migration is complete.
    ```bash
    aws dms start-replication-task \
      --replication-task-arn ${dms_task_arn} \
      --start-replication-task-type start-replication
    ```
*   **Initial Data**: A `null_resource` will invoke the `data-generator` Lambda to populate the source database immediately after DMS is running.
    ```bash
    aws lambda invoke --function-name ${lambda_name} response.json
    ```

### 2.3 Terraform Module Updates
*   **RDS Module**: Add outputs for endpoint and credentials.
*   **DMS Module**: Add outputs for the replication task ARN.
*   **Main Module**: Orchestrate the `null_resource` triggers to ensure correct ordering (RDS ➔ Flyway ➔ DMS ➔ Lambda).

## 3. Implementation Plan
1.  Set up the `db/migration` directory and migrate existing SQL scripts.
2.  Add required outputs to RDS and DMS modules.
3.  Implement the `null_resource` for Flyway migrations.
4.  Implement the `null_resource` for starting the DMS task and invoking Lambda.
5.  Verify the full flow by checking the S3 bronze folder.

## 4. Prerequisites
*   `flyway` CLI installed locally.
*   `aws` CLI configured with appropriate credentials.
*   RDS must be `publicly_accessible = true` (already configured).
